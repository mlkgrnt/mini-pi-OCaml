(* Subprocess plumbing.

   Why this module exists: on Windows, [select] does not work on pipes, so a
   pipe cannot be handed to the Lwt event loop the way it can on Unix. The
   portable way to read a child's output without stalling the Lwt scheduler is
   to do the blocking reads on a preemptive worker thread and marshal the
   results back with [Lwt_preemptive.run_in_main]. Everything that shells out
   (curl, the shell tool) goes through here, so the workaround lives in exactly
   one place. *)

type t = {
  pid : int;
  stdin_fd : Unix.file_descr;
  stdout_fd : Unix.file_descr;
  stderr_fd : Unix.file_descr option;
  mutable killed : bool;
}

let spawn_full ~(prog : string) ~(argv : string array) ~(merge_stderr : bool) : t =
  let in_r, in_w = Unix.pipe () in
  let out_r, out_w = Unix.pipe () in
  if merge_stderr then (
    let pid = Unix.create_process prog argv in_r out_w out_w in
    Unix.close in_r;
    Unix.close out_w;
    { pid; stdin_fd = in_w; stdout_fd = out_r; stderr_fd = None; killed = false })
  else
    let err_r, err_w = Unix.pipe () in
    let pid = Unix.create_process prog argv in_r out_w err_w in
    Unix.close in_r;
    Unix.close out_w;
    Unix.close err_w;
    { pid; stdin_fd = in_w; stdout_fd = out_r; stderr_fd = Some err_r; killed = false }

let spawn ~prog ~argv = spawn_full ~prog ~argv ~merge_stderr:false
let spawn_merged ~prog ~argv = spawn_full ~prog ~argv ~merge_stderr:true

(* There is deliberately no "write to the child's stdin" helper here.
   On Windows, a child spawned by [Unix.create_process] with a pipe made by
   [Unix.pipe] never observes EOF on that pipe. Any protocol where the child
   waits for stdin to end before doing its work therefore hangs forever -- most
   importantly `curl --data-binary @-`, which blocks before it even opens the
   connection. An earlier version of this module did have such a helper, and it
   swallowed every write error, so the write reported success and nothing
   anywhere pointed at the real problem.
   [ai_http] stages request bodies in a temp file and passes the path instead.
   [live/transport_probe.ml] reproduces the difference with curl's argv held
   fixed. If a future tool genuinely needs to feed a child, verify it with that
   probe first. *)
let close_stdin (p : t) = try Unix.close p.stdin_fd with _ -> ()

let kill (p : t) =
  if not p.killed then (
    p.killed <- true;
    (* On Windows Unix.kill only supports SIGKILL. *)
    try Unix.kill p.pid Sys.sigkill with _ -> ())

(* Blocks. Call from a preemptive thread. *)
let read_all_fd fd =
  let buf = Bytes.create 65536 in
  let b = Buffer.create 65536 in
  let rec go () =
    let n = try Unix.read fd buf 0 65536 with _ -> 0 in
    if n > 0 then (
      Buffer.add_subbytes b buf 0 n;
      go ())
  in
  go ();
  Buffer.contents b

let strip_cr s =
  let n = String.length s in
  if n > 0 && s.[n - 1] = '\r' then String.sub s 0 (n - 1) else s

(* Incremental line reader over a file descriptor. [f] is called for each
   complete line, newline stripped and trailing CR removed. *)
let iter_lines fd ~(f : string -> unit) =
  let buf = Bytes.create 65536 in
  let acc = Buffer.create 8192 in
  let flush_lines () =
    let s = Buffer.contents acc in
    let len = String.length s in
    let start = ref 0 in
    for i = 0 to len - 1 do
      if s.[i] = '\n' then (
        f (strip_cr (String.sub s !start (i - !start)));
        start := i + 1)
    done;
    let rest = String.sub s !start (len - !start) in
    Buffer.clear acc;
    Buffer.add_string acc rest
  in
  let rec go () =
    let n = try Unix.read fd buf 0 65536 with _ -> 0 in
    if n > 0 then (
      Buffer.add_subbytes acc buf 0 n;
      flush_lines ();
      go ())
    else if Buffer.length acc > 0 then f (strip_cr (Buffer.contents acc))
  in
  go ()

(* A stream of lines read from a file descriptor.

   Used for stdin in both the REPL and the RPC server. We cannot hand stdin to
   the Lwt event loop directly: on Windows, select does not work on pipes or
   console handles, so the read has to happen on a blocking worker thread and be
   handed back with [Lwt_preemptive.run_in_main]. Doing it once, here, keeps
   both interfaces on the same, portable path. *)
let line_stream (fd : Unix.file_descr) : string Lwt_stream.t =
  let stream, push = Lwt_stream.create () in
  Lwt.async (fun () ->
      Lwt_preemptive.detach
        (fun () ->
          iter_lines fd ~f:(fun line ->
              Lwt_preemptive.run_in_main (fun () ->
                  push (Some line);
                  Lwt.return_unit));
          (* Closing the stream is what tells the caller that stdin is done. *)
          Lwt_preemptive.run_in_main (fun () ->
              push None;
              Lwt.return_unit))
        ());
  stream

(* On-demand single-line read of stdin.

   The REPL needs this rather than [line_stream] because extension UI prompts
   ([select]) read from the same stdin as the main loop: with a continuously
   draining reader the answer to a prompt would be swallowed and buffered.
   Reading one line only when asked keeps the two in step. *)
let stdin_leftover = Buffer.create 256

let take_buffered_line () =
  let s = Buffer.contents stdin_leftover in
  match String.index_opt s '\n' with
  | None -> None
  | Some i ->
      let line = String.sub s 0 i in
      let rest = String.sub s (i + 1) (String.length s - i - 1) in
      Buffer.clear stdin_leftover;
      Buffer.add_string stdin_leftover rest;
      Some (strip_cr line)

let read_stdin_line () : string option Lwt.t =
  Lwt_preemptive.detach
    (fun () ->
      match take_buffered_line () with
      | Some l -> Some l
      | None ->
          let buf = Bytes.create 4096 in
          let rec go () =
            let n = try Unix.read Unix.stdin buf 0 4096 with _ -> 0 in
            if n > 0 then (
              Buffer.add_subbytes stdin_leftover buf 0 n;
              match take_buffered_line () with Some l -> Some l | None -> go ())
            else if Buffer.length stdin_leftover > 0 then (
              (* Last line without a trailing newline. *)
              let l = strip_cr (Buffer.contents stdin_leftover) in
              Buffer.clear stdin_leftover;
              Some l)
            else None
          in
          go ())
    ()

(* Reap the child and hand back its raw [process_status]; callers that want a
   numeric exit code go through [exit_code_of_status] below. *)
let wait (p : t) : Unix.process_status =
  match Unix.waitpid [] p.pid with _pid, status -> status

(* Spawn a child that keeps our own stdin/stdout/stderr. Needed for the TUI,
   which is a full-screen application and must own the terminal. *)
let spawn_inherit ~(prog : string) ~(argv : string array) : int =
  let pid = Unix.create_process prog argv Unix.stdin Unix.stdout Unix.stderr in
  match Unix.waitpid [] pid with _pid, status ->
    (match status with Unix.WEXITED c -> c | _ -> -1)

let exit_code_of_status = function
  | Unix.WEXITED c -> c
  | Unix.WSIGNALED _ | Unix.WSTOPPED _ -> -1

(* Read the child's stdout to EOF (the child's exit closes the pipe) and reap
   it. Blocking; wrap in Lwt_preemptive.detach. *)
let drain_and_wait (p : t) : string * int =
  let out = read_all_fd p.stdout_fd in
  let err = match p.stderr_fd with Some fd -> read_all_fd fd | None -> "" in
  let code = exit_code_of_status (wait p) in
  ((if err = "" then out else out ^ err), code)

(* --- shell helper ------------------------------------------------- *)

let is_windows = Sys.win32

(* Single-quote a string for POSIX sh. *)
let sh_quote s = "'" ^ String.concat "'\\''" (String.split_on_char '\'' s) ^ "'"

(* Double-quote a string for cmd.exe, which has no escape for embedded quotes;
   we drop them instead of silently producing a broken command line. *)
let cmd_quote s = "\"" ^ String.concat "" (String.split_on_char '"' s) ^ "\""

(* [Unix.create_process] has no notion of a working directory, so we change
   directory from inside the shell instead. *)
let with_cwd ~(cwd : string) ~(command : string) : string =
  if is_windows then
    if cwd = "" then command else Printf.sprintf "cd /d %s && %s" (cmd_quote cwd) command
  else if cwd = "" then command
  else Printf.sprintf "cd %s && %s" (sh_quote cwd) command

let default_shell () =
  match Sys.getenv_opt "MINI_PI_SHELL" with
  | Some s when String.trim s <> "" -> s
  | _ -> if is_windows then "cmd.exe" else "/bin/sh"

let shell_argv (shell : string) (command : string) : string array =
  if is_windows then [| shell; "/c"; command |] else [| shell; "-c"; command |]
