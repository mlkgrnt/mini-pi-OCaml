(* Port of coding/modes/cli/cli.py and coding/modes/cli/extension_ui.py *)

open Lwt.Syntax

let dim = "\027[90m"
let reset = "\027[0m"

let p fmt = Printf.ksprintf (fun s -> print_string s; flush stdout) fmt
let pn fmt = Printf.ksprintf (fun s -> print_string s; print_newline (); flush stdout) fmt

let clear_screen () = p "\027[2J\027[3J\027[H"

let cli_ui : Coding_extensions.ui =
  {
    select =
      (fun title options ->
        pn "%s" title;
        List.iteri (fun i o -> pn " %d. %s" (i + 1) o) options;
        p "Select [1-%d]: " (List.length options);
        let* line = Proc_util.read_stdin_line () in
        match line with
        | None -> Lwt.return_none
        | Some c -> (
            let c = String.trim c in
            match int_of_string_opt c with
            | Some n when n >= 1 && n <= List.length options ->
                Lwt.return (Some (List.nth options (n - 1)))
            | _ -> Lwt.return_none));
    notify =
      (fun message level ->
        pn "[%s] %s" level message);
  }

let print_session_history (messages : Coding_messages.session_message list) =
  List.iter
    (fun m ->
      match m with
      | Coding_messages.Msg (Ai_types.User u) -> pn "\nuser> %s" u.content
      | Coding_messages.Msg (Ai_types.Assistant a) ->
          pn "\nassistant>";
          if a.thinking <> "" then pn "%s[thinking]\n%s\n[thinking end]%s\n" dim a.thinking reset;
          if a.content <> "" then pn "%s" a.content;
          List.iter
            (fun (tc : Ai_types.tool_call) ->
              pn "\n[tool call] %s(%s)" tc.name (Yojson.Safe.to_string tc.arguments))
            a.tool_calls
      | Coding_messages.Msg (Ai_types.Tool_result r) ->
          let snippet =
            if String.length r.content > 200 then String.sub r.content 0 200 ^ "..." else r.content
          in
          pn "\n[tool output] %s: %s" r.tool_name (String.trim snippet)
      | Coding_messages.Compaction_summary s -> pn "\n[compacted summary]\n%s" s)
    messages

(* Returns true when the REPL should exit. *)
let handle_input (user_input : string) (rt : Coding_session_runtime.t) : bool Lwt.t =
  let name, args = Coding_commands.parse_command user_input in
  let session = rt.Coding_session_runtime.session in
  let csm = session.Coding_session.chat_session_manager in

  if name = "exit" then (
    pn "\nGoodBye";
    Lwt.return_true)
  else if name = "clear" then
    let* () = Coding_session_runtime.new_session rt in
    clear_screen ();
    pn "\nStarting new session: %s\n"
      rt.Coding_session_runtime.session.Coding_session.chat_session_manager.session_id;
    Lwt.return_false
  else if name = "session" then (
    pn "Active session: %s" csm.session_id;
    Lwt.return_false)
  else if name = "resume" then
    if args = "" then (
      let rows = Coding_session_manager.list_sessions () in
      pn "\nAvaliable Sessions:";
      List.iter
        (fun (r : Coding_session_manager.file_metadata) ->
          let t = String.sub r.updated_at 5 11 in
          pn "- %s | %s" t r.id)
        rows;
      pn "Use `/resume <id>` to switch\n";
      Lwt.return_false)
    else
      Lwt.catch
        (fun () ->
          let* () = Coding_session_runtime.switch_session rt args in
          clear_screen ();
          let s = rt.Coding_session_runtime.session in
          pn "\nResuming session: %s with %d messages\n"
            s.Coding_session.chat_session_manager.session_id
            (List.length s.Coding_session.harness.Agent_harness.messages);
          print_session_history s.Coding_session.harness.Agent_harness.messages;
          Lwt.return_false)
        (fun exn ->
          pn "%s" (Printexc.to_string exn);
          Lwt.return_false)
  else if name = "compact" then
    let* () =
      Coding_session.compact session ~reason:Coding_events.Manual
        ?custom_instructions:(if args = "" then None else Some args) ()
    in
    Lwt.return_false
  else if name = "login" then (
    let parts = List.filter (fun s -> s <> "") (String.split_on_char ' ' (String.trim args)) in
    match parts with
    | provider :: key :: _ ->
        Coding_auth.set_api_key_to_auth provider key;
        pn "Saved API key for %s" provider;
        Lwt.return_false
    | _ ->
        pn "Usage: /login <provider> <key>";
        Lwt.return_false)
  else if name = "help" then (
    let lines = ref [ "Available built in commands" ] in
    List.iter
      (fun (c : Coding_commands.builtin) ->
        let hint = match c.argument_hint with Some h -> " " ^ h | None -> "" in
        lines := !lines @ [ Printf.sprintf " /%s%s - %s" c.name hint c.description ])
      Coding_commands.builtin_slash_commands;
    (match session.Coding_session.config.extension_runtime with
    | Some er ->
        let builtin_names = List.map (fun (c : Coding_commands.builtin) -> c.name) Coding_commands.builtin_slash_commands in
        let ext = Coding_extensions.get_all_commands er in
        if ext <> [] then lines := !lines @ [ "Available extension commands" ];
        List.iter
          (fun (c : Coding_extensions.command) ->
            if not (List.mem c.name builtin_names) then
              lines := !lines @ [ Printf.sprintf " /%s - %s" c.name c.description ])
          ext
    | None -> ());
    pn "\n%s\n" (String.concat "\n" !lines);
    Lwt.return_false)
  else
    let* () = Coding_session.prompt session user_input in
    Lwt.return_false

let run (rt : Coding_session_runtime.t) : unit Lwt.t =
  let session_unsubscribe : (unit -> unit) option ref = ref None in
  let in_thinking = ref false in

  let print_event (event : Coding_events.t) =
    match event with
    | Coding_events.Agent Agent_events.Message_start m -> (
        match m with
        | Coding_messages.Msg (Ai_types.Assistant _) ->
            in_thinking := false;
            pn "\nassistant>"
        | _ -> ())
    | Coding_events.Agent (Agent_events.Message_update delta) -> (
        match delta with
        | Agent_events.Thinking_delta d ->
            if not !in_thinking then (
              pn "%s[thinking]%s" dim reset;
              in_thinking := true);
            p "%s%s%s" dim d reset
        | Agent_events.Text_delta d ->
            if !in_thinking then (
              in_thinking := false;
              pn "\n%s[thinking end]%s\n" dim reset);
            p "%s" d)
    | Coding_events.Agent (Agent_events.Tool_execution_start { tool_name; arguments; _ }) ->
        pn "\n\n[tool call] %s(%s)" tool_name (Yojson.Safe.to_string arguments)
    | Coding_events.Agent (Agent_events.Tool_execution_end { tool_name; result; _ }) ->
        let snippet = if String.length result > 200 then String.sub result 0 200 ^ "..." else result in
        pn "\n[tool output] %s: %s" tool_name (String.trim snippet)
    | Coding_events.Agent (Agent_events.Message_end m) -> (
        match m with
        | Coding_messages.Msg (Ai_types.Assistant a) ->
            if !in_thinking then in_thinking := false;
            (match a.stop_reason with
            | Some (Ai_types.Error | Ai_types.Aborted) ->
                pn "\n\n[%s] %s"
                  (Ai_types.stop_reason_to_string (Option.get a.stop_reason))
                  (Option.value ~default:"" a.error_message)
            | _ -> ())
        | _ -> ())
    | Coding_events.Compaction_start reason ->
        pn "\n[compaction] started (%s)" (Coding_events.compaction_reason_to_string reason)
    | Coding_events.Compaction_end { result; error_message } -> (
        match error_message with
        | Some e -> pn "\n[compaction] failed: %s" e
        | None -> pn "\n[compaction] %s" (Option.value ~default:"" result))
    | _ -> ()
  in

  let print_event_lwt ev =
    print_event ev;
    Lwt.return_unit
  in

  let rebind (s : Coding_session.t) =
    (match !session_unsubscribe with Some f -> f () | None -> ());
    (match s.Coding_session.config.extension_runtime with
    | Some er -> Coding_extensions.set_ui er (Some cli_ui)
    | None -> ());
    session_unsubscribe := Some (Coding_session.subscribe s print_event_lwt)
  in

  pn "Mini Pi started with model '%s'. Session: %s.\n"
    rt.Coding_session_runtime.session.Coding_session.config.model.Ai_types.name
    rt.Coding_session_runtime.session.Coding_session.chat_session_manager.session_id;

  Coding_session_runtime.set_rebind_session rt rebind;
  rebind rt.Coding_session_runtime.session;

  let rec loop () =
    p "user> ";
    let* line = Proc_util.read_stdin_line () in
    match line with
    | None -> Lwt.return_unit
    | Some raw ->
        let user_input = String.trim raw in
        if user_input = "" then loop ()
        else (
          in_thinking := false;
          let* exit_status =
            Lwt.catch
              (fun () -> handle_input user_input rt)
              (fun _ ->
                pn "\n[Interrupted by user]\n";
                Lwt.return_false)
          in
          if exit_status then Lwt.return_unit
          else (
            pn "\n";
            loop ()))
  in
  loop ()
