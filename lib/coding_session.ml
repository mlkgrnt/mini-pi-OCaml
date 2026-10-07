(* Port of coding/session.py

   The coding session sits between the agent harness and the persisted session
   tree: it mirrors every finished message into the tree, decides when to
   compact, and exposes rewind / steer / follow-up to the interfaces. *)

open Lwt.Syntax

type rewind_target = { entry_id : string; text : string }

type config = {
  mutable model : Ai_types.ai_model;
  system : string;
  chat_session_manager : Coding_session_manager.t;
  compaction_settings : Coding_compaction.settings;
  tools : Agent_tools.t list;
  extension_runtime : Coding_extensions.runtime option;
}

type t = {
  config : config;
  harness : Coding_messages.session_message Agent_harness.t;
  chat_session_manager : Coding_session_manager.t;
  mutable listeners : (Coding_events.t -> unit Lwt.t) list;
  mutable compaction_signal : Ai_cancellation.t option;
}

(* Extension tools take precedence over built-ins of the same name, without
   disturbing the order of the built-ins. *)
let merge_tools (base : Agent_tools.t list) (extras : Agent_tools.t list) : Agent_tools.t list =
  let tbl = Hashtbl.create 8 in
  List.iter (fun (t : Agent_tools.t) -> Hashtbl.replace tbl t.name t) base;
  List.iter (fun (t : Agent_tools.t) -> Hashtbl.replace tbl t.name t) extras;
  let seen = Hashtbl.create 8 in
  let out = ref [] in
  let add (t : Agent_tools.t) =
    if not (Hashtbl.mem seen t.name) then (
      Hashtbl.add seen t.name ();
      out := !out @ [ Hashtbl.find tbl t.name ])
  in
  List.iter add base;
  List.iter add extras;
  !out

let rec load (config : config) : t Lwt.t =
  let csm = config.chat_session_manager in
  let context = Coding_session_manager.build_session_context csm in

  let effective_tools =
    match config.extension_runtime with
    | None -> config.tools
    | Some rt ->
        merge_tools config.tools (Coding_extensions.get_all_tools rt)
        |> List.map (Coding_extensions.wrap_tool rt)
  in

  let harness_config : Coding_messages.session_message Agent_harness.config =
    {
      stream_fn = Ai_registry.stream;
      model = config.model;
      system = config.system;
      tools = effective_tools;
      of_llm = Coding_messages.of_llm;
      to_llm = Coding_messages.to_llm_list;
    }
  in

  let harness = Agent_harness.create harness_config context.messages in

  let session =
    {
      config;
      harness;
      chat_session_manager = csm;
      listeners = [];
      compaction_signal = None;
    }
  in
  (* [subscribe] returns an unsubscribe closure. The session lives as long as the
     process does, so it is never called; bind it to a named value rather than
     dropping it, otherwise the discarded function value reads as a forgotten
     argument (warning 5). *)
  let _unsubscribe = Agent_harness.subscribe harness (fun ev -> on_agent_event session ev) in
  Lwt.return session

and on_agent_event (t : t) (event : Coding_messages.session_message Agent_events.t) : unit Lwt.t =
  (match event with
  | Agent_events.Message_end m -> ignore (Coding_session_manager.append_message t.chat_session_manager m)
  | _ -> ());
  notify t (Coding_events.Agent event)

and notify (t : t) (event : Coding_events.t) : unit Lwt.t =
  let snapshot = t.listeners in
  Lwt_list.iter_s
    (fun l -> Lwt.catch (fun () -> l event) (fun _ -> Lwt.return_unit))
    snapshot

let set_model (t : t) (model : Ai_types.ai_model) =
  t.config.model <- model;
  t.harness.config.model <- model

let subscribe (t : t) (listener : Coding_events.t -> unit Lwt.t) : unit -> unit =
  t.listeners <- t.listeners @ [ listener ];
  fun () -> t.listeners <- List.filter (fun l -> l != listener) t.listeners

let is_compacting (t : t) = t.compaction_signal <> None

(* Usage reported by a message that predates the newest compaction is stale:
   the prompt it measured no longer exists. *)
let is_usage_stale (t : t) : bool =
  let rec walk = function
    | [] -> false
    | e :: rest -> (
        match e with
        | Coding_entries.Compaction _ -> true
        | Coding_entries.Message m -> (
            match Coding_messages.as_assistant m.message with
            | Some a -> (
                match Coding_compaction.extract_usage_tokens a with
                | Some _ -> false
                | None -> walk rest)
            | None -> walk rest)
        | Coding_entries.Header _ -> walk rest)
  in
  walk (List.rev (Coding_session_manager.get_active_branch t.chat_session_manager))

let last_assistant_message (t : t) : Ai_types.assistant_message option =
  List.fold_left
    (fun acc m -> match Coding_messages.as_assistant m with Some a -> Some a | None -> acc)
    None t.harness.messages

let should_auto_compact (t : t) : bool =
  let s = t.config.compaction_settings in
  if not s.enabled then false
  else
    let tokens =
      if is_usage_stale t then
        List.fold_left (fun acc m -> acc + Coding_compaction.estimate_message_tokens m) 0
          t.harness.messages
      else Coding_compaction.estimate_context_tokens t.harness.messages
    in
    Coding_compaction.check_compaction_threshold ~context_tokens:tokens
      ~context_window:t.config.model.context_window s

let rewind_targets (t : t) : rewind_target list Lwt.t =
  if t.chat_session_manager.leaf_id = None then Lwt.return []
  else
    Lwt.return
      (List.rev_map
         (fun e ->
           match e with
           | Coding_entries.Message m ->
               {
                 entry_id = Coding_entries.id e;
                 text = (match m.message with
                        | Coding_messages.Msg (Ai_types.User u) -> u.content
                        | _ -> "");
               }
           | _ -> { entry_id = Coding_entries.id e; text = "" })
         (Coding_session_manager.rewind_entries t.chat_session_manager))

let rewind_to (t : t) (entry_id : string) : Coding_messages.session_message list Lwt.t =
  if t.harness.is_running || is_compacting t then
    Lwt.fail (Failure "Cannot rewind while another request is running")
  else if t.chat_session_manager.leaf_id = None then Lwt.return []
  else
    let targets = Coding_session_manager.rewind_entries t.chat_session_manager in
    match List.find_opt (fun e -> Coding_entries.id e = entry_id) targets with
    | None -> Lwt.fail (Failure (Printf.sprintf "Unknown session entry: %s" entry_id))
    | Some target ->
        Coding_session_manager.branch t.chat_session_manager
          (Option.value ~default:"" (Coding_entries.parent_id target));
        let context = Coding_session_manager.build_session_context t.chat_session_manager in
        Agent_harness.replace_messages t.harness context.messages;
        Lwt.return context.messages

let run_input_hooks (t : t) (content : string) : string option Lwt.t =
  match t.config.extension_runtime with
  | None -> Lwt.return (Some content)
  | Some rt ->
      let* res = Coding_extensions.run_input_hooks rt content in
      (match res.action with
      | Coding_extensions.Handled -> Lwt.return_none
      | Coding_extensions.Transform ->
          Lwt.return (match res.text with Some t -> Some t | None -> Some content)
      | Coding_extensions.Continue -> Lwt.return (Some content))

let steer (t : t) (content : string) : unit Lwt.t =
  let* effective = run_input_hooks t content in
  match effective with
  | None -> Lwt.return_unit
  | Some c ->
      Agent_queue.steer t.harness.msg_queue_when_running c;
      Lwt.return_unit

let follow_up (t : t) (content : string) : unit Lwt.t =
  let* effective = run_input_hooks t content in
  match effective with
  | None -> Lwt.return_unit
  | Some c ->
      Agent_queue.follow_up t.harness.msg_queue_when_running c;
      Lwt.return_unit

let try_execute_extension_command (t : t) (text : string) : bool Lwt.t =
  match t.config.extension_runtime with
  | None -> Lwt.return_false
  | Some rt ->
      let body = String.sub text 1 (String.length text - 1) in
      let name, args =
        match String.index_opt body ' ' with
        | None -> (body, "")
        | Some i -> (String.sub body 0 i, String.sub body (i + 1) (String.length body - i - 1))
      in
      (match Coding_extensions.get_command rt name with
      | None -> Lwt.return_false
      | Some cmd ->
          let* () = Lwt.catch (fun () -> cmd.handler args rt.context) (fun _ -> Lwt.return_unit) in
          Lwt.return_true)

let rec compact (t : t) ~(reason : Coding_events.compaction_reason)
    ?(custom_instructions : string option) () : unit Lwt.t =
  if t.harness.is_running || is_compacting t then Lwt.return_unit
  else (
    let* () = notify t (Coding_events.Compaction_start reason) in
    let signal = Ai_cancellation.create () in
    t.compaction_signal <- Some signal;

    let finish (ev : Coding_events.t) =
      t.compaction_signal <- None;
      notify t ev
    in

    let body () =
      let context = Coding_session_manager.build_session_context t.chat_session_manager in
      match Coding_compaction.prepare_compaction context.messages_entries t.config.compaction_settings with
      | None ->
          finish
            (Coding_events.Compaction_end
               { result = None; error_message = Some "Unable to find valid cut point" })
      | Some preparation ->
          let* summary =
            Coding_compaction.generate_compaction_summary ~stream_fn:t.harness.config.stream_fn
              ~model:t.config.model ~messages_to_summarize:preparation.messages_to_summarize
              ?custom_instructions ?previous_summary:preparation.previous_summary
              ~signal:(Some signal) ()
          in

          if Ai_cancellation.is_cancelled signal then
            finish
              (Coding_events.Compaction_end
                 { result = None; error_message = Some "Compaction Cancelled" })
          else
            let file_ops =
              Coding_compaction.format_file_operations preparation.messages_to_summarize
            in
            let summary = if file_ops = "" then summary else summary ^ "\n\n" ^ file_ops in
            ignore
              (Coding_session_manager.append_compaction t.chat_session_manager ~summary
                 ~first_kept_entry_id:preparation.first_kept_entry_id);
            let context = Coding_session_manager.build_session_context t.chat_session_manager in
            Agent_harness.replace_messages t.harness context.messages;
            finish
              (Coding_events.Compaction_end
                 {
                   result =
                     Some
                       (Printf.sprintf "Compacted %d messages"
                          (List.length preparation.messages_to_summarize));
                   error_message = None;
                 })
    in

    Lwt.catch body (fun exn ->
        finish (Coding_events.Compaction_end { result = None; error_message = Some (Printexc.to_string exn) })))

and prompt (t : t) (content : string) : unit Lwt.t =
  if is_compacting t then Lwt.return_unit
  else if t.harness.is_running then Lwt.return_unit
  else
    let* handled =
      if String.length content > 0 && content.[0] = '/' then try_execute_extension_command t content
      else Lwt.return_false
    in
    if handled then Lwt.return_unit
    else
      let* effective = run_input_hooks t content in
      match effective with
      | None -> Lwt.return_unit
      | Some effective ->
          let* () = if should_auto_compact t then compact t ~reason:Coding_events.Threshold () else Lwt.return_unit in
          let* () = Agent_harness.prompt t.harness effective in
          (match last_assistant_message t with
          | Some last
            when last.stop_reason <> Some Ai_types.Aborted && should_auto_compact t ->
              compact t ~reason:Coding_events.Threshold ()
          | _ -> Lwt.return_unit)

let cancel (t : t) =
  Agent_harness.cancel t.harness;
  match t.compaction_signal with Some s -> Ai_cancellation.cancel s | None -> ()
