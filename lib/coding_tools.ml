(* Port of coding/tools/{read,write,edit,bash}.py

   Four tools: read, write, edit, bash. The bash tool is the only one that
   needs a sandbox in the Python original (bubblewrap, Linux only); here
   [is_sandbox_available] simply reports false on platforms without bwrap, which
   is what drives the bundled permission_gate extension into "ask" mode. *)

open Lwt.Syntax
open Coding_tool_utils

let str_arg args name = match Ai_json.str_opt args name with Some s -> Some s | None -> None

(* ------------------------------------------------------------------ *)
(* read                                                                *)
(* ------------------------------------------------------------------ *)

let create_read_tool ~(cwd : string) : Agent_tools.t =
  let execute (args : Yojson.Safe.t) (_signal : Ai_cancellation.t option) : string Lwt.t =
    let raw_path =
      match str_arg args "path" with
      | Some p when p <> "" -> p
      | _ -> tool_error "path is required"
    in
    let offset = match Ai_json.int_opt args "offset" with Some o when o > 0 -> o | _ -> 1 in
    let limit = match Ai_json.int_opt args "limit" with Some l when l > 0 -> Some l | _ -> None in
    let resolved = resolve_path ~cwd raw_path in

    if not (Sys.file_exists resolved) then
      tool_error (Printf.sprintf "Path '%s' does not exist" resolved);
    if Sys.is_directory resolved then tool_error (Printf.sprintf "'%s' is not file" resolved);

    let content = read_file_text resolved in
    if content = "" then Lwt.return ""
    else
      let lines = Array.of_list (split_lines content) in
      let total_lines = Array.length lines in

      if offset > total_lines then
        tool_error
          (Printf.sprintf "Offset %d is beyond end of file (%d) lines total" offset total_lines);

      let start_index = offset - 1 in
      let selected =
        match limit with
        | None -> Array.to_list (Array.sub lines start_index (total_lines - start_index))
        | Some l ->
            let l = min l (total_lines - start_index) in
            if l <= 0 then [] else Array.to_list (Array.sub lines start_index l)
      in

      let selected_text = String.concat "\n" selected in
      let truncated = truncate selected_text Head in

      let numbered =
        truncated.Coding_tool_utils.output |> split_lines
        |> List.mapi (fun i l -> Printf.sprintf "%d. %s" (i + offset) l)
        |> String.concat "\n"
      in

      let numbered =
        if truncated.truncated then
          numbered
          ^ Printf.sprintf "\n\n[Showing first %s] of %s. Use offset to read subsequent lines. Last line may be partial]"
              (format_size truncated.output_bytes)
              (format_size truncated.total_bytes)
        else numbered
      in
      Lwt.return numbered
  in
  {
    Agent_tools.name = "read";
    description = "Read the contents of a text file with offset and limit for line ranges";
    parameters =
      `Assoc
        [
          ("type", `String "object");
          ( "properties",
            `Assoc
              [
                ("path", `Assoc [ ("type", `String "string"); ("description", `String "Path to file to read") ]);
                ( "offset",
                  `Assoc
                    [
                      ("type", `String "integer");
                      ("description", `String "Line number to start reading from (1-indexed)");
                    ] );
                ("limit", `Assoc [ ("type", `String "integer"); ("description", `String "Number of lines to read") ]);
              ] );
          ("required", `List [ `String "path" ]);
        ];
    execute;
  }

(* ------------------------------------------------------------------ *)
(* write                                                               *)
(* ------------------------------------------------------------------ *)

let create_write_tool ~(cwd : string) : Agent_tools.t =
  let execute (args : Yojson.Safe.t) (_signal : Ai_cancellation.t option) : string Lwt.t =
    let raw_path =
      match str_arg args "path" with
      | Some p when p <> "" -> p
      | _ -> tool_error "path is required"
    in
    let content = match str_arg args "content" with Some c -> c | None -> "" in
    let resolved = resolve_path ~cwd raw_path in

    if Sys.file_exists resolved && Sys.is_directory resolved then
      tool_error (Printf.sprintf "'%s' exist and is not a file" resolved);

    write_file_text resolved content;
    Lwt.return (Printf.sprintf "Successfully wrote %d characters to '%s'" (String.length content) raw_path)
  in
  {
    Agent_tools.name = "write";
    description =
      "Write content to a file. Creates the file if it doesn't exist, overwrites if it does.";
    parameters =
      `Assoc
        [
          ("type", `String "object");
          ( "properties",
            `Assoc
              [
                ("path", `Assoc [ ("type", `String "string"); ("description", `String "Path to the file to write") ]);
                ( "content",
                  `Assoc
                    [ ("type", `String "string"); ("description", `String "Content to write to the file") ] );
              ] );
          ("required", `List [ `String "path"; `String "content" ]);
        ];
    execute;
  }

(* ------------------------------------------------------------------ *)
(* edit                                                                *)
(* ------------------------------------------------------------------ *)

let create_edit_tool ~(cwd : string) : Agent_tools.t =
  let execute (args : Yojson.Safe.t) (_signal : Ai_cancellation.t option) : string Lwt.t =
    let raw_path =
      match str_arg args "path" with
      | Some p when p <> "" -> p
      | _ -> tool_error "path is required"
    in
    let old_string = match str_arg args "old_string" with Some s -> s | None -> "" in
    let new_string = match str_arg args "new_string" with Some s -> s | None -> "" in

    if old_string = "" then tool_error "'old_string' cannot be empty";

    let resolved = resolve_path ~cwd raw_path in
    if not (Sys.file_exists resolved) then
      tool_error (Printf.sprintf "Path '%s' does not exist" resolved);
    if Sys.is_directory resolved then tool_error (Printf.sprintf "'%s' is not file" resolved);

    let content = read_file_text resolved in
    let count = count_occurrences content old_string in

    if count = 0 then tool_error (Printf.sprintf "Could not find old_string in %s" raw_path)
    else if count > 1 then
      tool_error
        (Printf.sprintf
           "Found %d occurences of old_string in %s. old_string must have only one occurance" count
           raw_path)
    else (
      write_file_text resolved (replace_first content old_string new_string);
      Lwt.return (Printf.sprintf "Successfully edited '%s'" raw_path))
  in
  {
    Agent_tools.name = "edit";
    description =
      "Edit a file by replacing an exact unique occurrence of old_string with new_string.";
    parameters =
      `Assoc
        [
          ("type", `String "object");
          ( "properties",
            `Assoc
              [
                ("path", `Assoc [ ("type", `String "string"); ("description", `String "Path to the file to edit") ]);
                ( "old_string",
                  `Assoc
                    [
                      ("type", `String "string");
                      ("description", `String "Exact string to find and replace. Must match uniquely.");
                    ] );
                ( "new_string",
                  `Assoc
                    [ ("type", `String "string"); ("description", `String "String to replace old_string with") ] );
              ] );
          ("required", `List [ `String "path"; `String "old_string"; `String "new_string" ]);
        ];
    execute;
  }

(* ------------------------------------------------------------------ *)
(* bash                                                                *)
(* ------------------------------------------------------------------ *)

let is_sandbox_available () = command_exists "bwrap"

type exec_result =
  | Completed of string * int (* output, exit code *)
  | Timed_out
  | Cancelled

let run_shell ~(cwd : string) ~(command : string) ~(timeout : float)
    ~(signal : Ai_cancellation.t option) : exec_result Lwt.t =
  let shell = Proc_util.default_shell () in
  let full_command = Proc_util.with_cwd ~cwd ~command in
  let p =
    Proc_util.spawn_merged ~prog:shell ~argv:(Proc_util.shell_argv shell full_command)
  in
  Proc_util.close_stdin p;

  (* The child's stdout is read to EOF on a worker thread; killing the child
     closes the pipe, which is what unblocks it. *)
  let reader = Lwt_preemptive.detach (fun () -> Proc_util.drain_and_wait p) () in

  let timeout_promise =
    let* () = Lwt_unix.sleep timeout in
    Lwt.return `Timeout
  in
  let cancel_promise =
    match signal with
    | Some s ->
        let* () = Ai_cancellation.wait s in
        Lwt.return `Cancelled
    | None -> fst (Lwt.wait ())
  in

  let* outcome =
    Lwt.pick [ (let* r = reader in Lwt.return (`Done r)); cancel_promise; timeout_promise ]
  in

  match outcome with
  | `Done (output, code) -> Lwt.return (Completed (output, code))
  | `Timeout ->
      Proc_util.kill p;
      let* _ = Lwt.catch (fun () -> reader) (fun _ -> Lwt.return ("", 0)) in
      Lwt.return Timed_out
  | `Cancelled ->
      Proc_util.kill p;
      let* _ = Lwt.catch (fun () -> reader) (fun _ -> Lwt.return ("", 0)) in
      Lwt.return Cancelled

(* Python renders the timeout as a float, e.g. "60.0". *)
let float_to_string f =
  if Float.is_integer f && Float.abs f < 1e15 then Printf.sprintf "%.1f" f else string_of_float f

let create_bash_tool ~(cwd : string) : Agent_tools.t =
  let execute (args : Yojson.Safe.t) (signal : Ai_cancellation.t option) : string Lwt.t =
    let command =
      match str_arg args "command" with
      | Some c when c <> "" -> c
      | _ -> tool_error "command is required"
    in
    let timeout =
      match Ai_json.member "timeout" args with
      | Some (`Int i) -> float_of_int i
      | Some (`Float f) -> f
      | _ -> 60.0
    in
    let timeout = if timeout <= 0.0 then 60.0 else timeout in

    let* result = run_shell ~cwd ~command ~timeout ~signal in
    match result with
    | Timed_out ->
        Lwt.return (Printf.sprintf "Error: Command timed out after %s seconds" (float_to_string timeout))
    | Cancelled -> Lwt.return "Error: Command Cancelled by user"
    | Completed (output, exit_code) ->
        let stdout = if output = "" then "(no output)" else output in
        let truncated = truncate stdout Tail in
        let out = ref truncated.output in
        if truncated.truncated then
          out :=
            !out
            ^ Printf.sprintf "\n\n[Showing last %s of %s.]"
                (format_size truncated.output_bytes)
                (format_size truncated.total_bytes);
        if exit_code <> 0 then
          out := !out ^ Printf.sprintf "\n[Process exited with code %d]" exit_code;
        Lwt.return !out
  in
  {
    Agent_tools.name = "bash";
    description = "Execute shell command. Returns stdout and stderr.";
    parameters =
      `Assoc
        [
          ("type", `String "object");
          ( "properties",
            `Assoc
              [
                ( "command",
                  `Assoc
                    [ ("type", `String "string"); ("description", `String "The shell command to execute") ] );
                ( "timeout",
                  `Assoc
                    [
                      ("type", `String "number");
                      ("description", `String "Optional timeout in seconds (default: 60)");
                    ] );
              ] );
          ("required", `List [ `String "command" ]);
        ];
    execute;
  }

let create_all ~(cwd : string) : Agent_tools.t list =
  [
    create_bash_tool ~cwd;
    create_read_tool ~cwd;
    create_write_tool ~cwd;
    create_edit_tool ~cwd;
  ]
