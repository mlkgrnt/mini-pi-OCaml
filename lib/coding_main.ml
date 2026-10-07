(* Port of coding/main.py and coding/entrypoint.py *)

open Lwt.Syntax

let version = "0.1.3"

let usage =
  String.concat "\n"
    [
      "minipi - a lightweight coding agent (OCaml port)";
      "";
      "Usage: minipi [--mode cli|rpc] [--tui] [--version]";
      "";
      "  --mode cli    line-oriented REPL (default when no TUI is available)";
      "  --mode rpc    newline-delimited JSON on stdin/stdout; this is what the TUI drives";
      "  --tui         force launching the bundled Node TUI";
      "";
    ]

let async_exception_hook exn =
  Printf.eprintf "[error] unhandled async exception: %s\n%!" (Printexc.to_string exn)

let find_node () = Coding_tool_utils.command_exists "node"

(* Mirrors entrypoint.py: prefer the TUI, fall back to the REPL when Node or the
   bundle is missing. The bundle path is overridable so a packaged install can
   point at it explicitly. *)
let tui_bundle () =
  match Sys.getenv_opt "MINI_PI_TUI" with
  | Some p when p <> "" -> Some p
  | _ ->
      let candidates =
        [
          Filename.concat (Filename.dirname Sys.executable_name) "mini-pi-tui.mjs";
          Filename.concat (Filename.dirname Sys.executable_name) "../tui/dist/mini-pi-tui.mjs";
          "tui/dist/mini-pi-tui.mjs";
        ]
      in
      List.find_opt (fun p -> Sys.file_exists p) candidates

let run_tui (extra_args : string list) : int =
  match tui_bundle () with
  | None ->
      Printf.eprintf "[WARNING] TUI bundle not found, launching the REPL-based CLI instead\n%!";
      127
  | Some bundle ->
      if not (find_node ()) then (
        Printf.eprintf
          "[WARNING] 'node' not found on PATH. Install Node.js from https://nodejs.org/en/download; the TUI needs it, so the REPL-based CLI is launching instead\n%!";
        127)
      else
        (* The TUI is a full-screen app: it inherits our terminal rather than
           talking over pipes. It drives the child process we hand it. *)
        let argv = Array.of_list ([ "node"; bundle ] @ extra_args) in
        let code = Proc_util.spawn_inherit ~prog:"node" ~argv in
        Printf.eprintf "[tui] exited with code %d\n%!" code;
        0

let run_mode (mode : [ `Cli | `Rpc ]) : unit =
  Lwt_main.run
    (let* config = Coding_session_factory.build_session_config () in
     let* session = Coding_session.load config in
     let rt = Coding_session_runtime.create session in
     match mode with `Rpc -> Coding_rpc.run rt | `Cli -> Coding_cli.run rt)

let main () : unit =
  Sys.catch_break true;
  Lwt.async_exception_hook := async_exception_hook;

  let argv = Array.to_list Sys.argv in
  let args = match argv with _ :: tl -> tl | [] -> [] in
  let mode = ref None and force_tui = ref false in

  let rec parse = function
    | [] -> ()
    | "--mode" :: m :: rest ->
        mode := Some m;
        parse rest
    | "--tui" :: rest ->
        force_tui := true;
        parse rest
    | "--version" :: _ ->
        print_endline version;
        exit 0
    | ("--help" | "-h") :: _ ->
        print_string usage;
        exit 0
    | _ :: rest -> parse rest
  in
  parse args;

  try
    match !mode with
    | Some "rpc" -> run_mode `Rpc
    | Some "cli" -> run_mode `Cli
    | Some other ->
        Printf.eprintf "unknown mode: %s\n" other;
        exit 2
    | None ->
        (* No explicit mode: hand over to the TUI when one is available. *)
        let tui_args =
          args
          |> List.filter (fun a -> a <> "--tui")
        in
        let code = run_tui tui_args in
        if code = 127 then run_mode `Cli
  with
  | Sys.Break -> ()
  | Lwt.Canceled -> ()
  | Failure msg ->
      Printf.eprintf "[error] %s\n%!" msg;
      exit 1
