(* HTTP transport.

   The original leans on httpx. Here the transport is [curl] invoked as a child
   process, which is a deliberate choice: it keeps TLS, proxy configuration,
   connection reuse and certificate validation out of our dependency tree, and
   it is the one HTTP stack that is guaranteed present and correct on Windows.

   Everything above this module is transport agnostic: [post_stream] is the only
   entry point, so swapping in a native OCaml client later means replacing the
   body of one function. *)

open Lwt.Syntax

type meta = { status : int; headers : (string * string) list }

let starts_with s prefix =
  String.length s >= String.length prefix && String.sub s 0 (String.length prefix) = prefix

let parse_status_line line =
  match String.split_on_char ' ' (String.trim line) with
  | _ :: code :: _ -> (match int_of_string_opt code with Some c -> c | None -> 0)
  | _ -> 0

let find_curl () =
  (* curl ships with Windows 10+ and with every Unix; the Cygwin environment
     that opam installs also provides one. *)
  "curl"

(* ------------------------------------------------------------------ *)
(* Response head parsing                                               *)
(* ------------------------------------------------------------------ *)

(* [curl -i] prefixes the body with the response head, but the output is not
   always a single head. Behind a proxy it is two: the proxy's reply to CONNECT,
   then the origin's real response:

     HTTP/1.1 200 Connection Established
     <blank>
     HTTP/1.1 401 Unauthorized
     Content-Type: application/json
     <blank>
     {"error": ...}

   A parser that treats the first blank line as the end of the head -- which an
   earlier version of this module did -- takes the proxy's status for the real
   one, never reports an error status, and throws away Retry-After. It appears
   to work, because the origin's header lines are then handed to the SSE reader,
   which simply ignores anything that does not start with [data:]. That is a
   silent misreading of a failure, so the head is parsed by an explicit state
   machine and covered by tests instead.

   The rule: a blank line ends a head, and a head is only the *last* one if what
   follows is not another status line. So nothing is delivered at the blank
   line; the decision waits for the next line. *)

type reader = {
  mutable in_headers : bool;
  mutable block_ended : bool;
  mutable reader_status : int;
  mutable reader_headers : (string * string) list;
  mutable delivered : bool;
}

type action = [ `Headers of meta | `Body of string ]

let new_reader () =
  { in_headers = true; block_ended = false; reader_status = 0; reader_headers = []; delivered = false }

let take_headers (r : reader) : action list =
  if r.delivered then []
  else (
    r.delivered <- true;
    [ `Headers { status = r.reader_status; headers = List.rev r.reader_headers } ])

let reader_line (r : reader) (line : string) : action list =
  if not r.in_headers then [ `Body line ]
  else if line = "" then (
    r.block_ended <- true;
    [])
  else if starts_with line "HTTP/" then (
    (* A new head: the previous block was an intermediate one (a proxy CONNECT
       reply, or 100 Continue), so its status and headers are discarded. *)
    r.block_ended <- false;
    r.reader_status <- parse_status_line line;
    r.reader_headers <- [];
    [])
  else if r.block_ended then (
    (* The blank line ended the head and this is not another status line, so it
       is the first body line. Deliver the head in front of it. *)
    r.in_headers <- false;
    take_headers r @ [ `Body line ])
  else (
    (match String.index_opt line ':' with
    | Some i ->
        let k = String.sub line 0 i in
        let v = String.trim (String.sub line (i + 1) (String.length line - i - 1)) in
        r.reader_headers <- (k, v) :: r.reader_headers
    | None -> ());
    [])

(* The stream ended. A response whose head arrived but whose body never produced
   a line -- or which was cut off mid-head -- must still report its status. *)
let reader_finish (r : reader) : action list = if r.in_headers then take_headers r else []

let post_stream ~(url : string) ~(headers : (string * string) list) ~(body : string)
    ~(timeout : float) ~(signal : Ai_cancellation.t option)
    ~(on_headers : meta -> unit Lwt.t) ~(on_line : string -> unit Lwt.t) () :
    [ `Ok | `Cancelled | `Timeout | `Transport_error of string ] Lwt.t =
  let speed_time = max 1 (int_of_float timeout) in

  (* The request body is handed to curl as a *file*, never on stdin.
     `--data-binary @-` makes curl read stdin to EOF before it opens the
     connection at all. On Windows a child spawned by [Unix.create_process] does
     not get a usable stdin from [Unix.pipe]: the parent's write succeeds and it
     closes its end, but the child never observes EOF, so curl waits forever and
     the request is never sent. Measured with [live/transport_probe.ml], which
     holds curl's argv fixed and varies only the body source: stdin hangs
     indefinitely with zero bytes of output, while @<file> returns a complete
     SSE stream in about three seconds.

     Staging to a file also removes the need to feed a large context through a
     pipe while the response is being read. *)
  let body_path = Filename.temp_file "minipi-request" ".json" in
  let remove_body () = try Sys.remove body_path with _ -> () in
  (try
     (* Binary, or a text-mode handle would rewrite '\n' to '\r\n'. *)
     let oc = open_out_bin body_path in
     output_string oc body;
     close_out oc
   with e ->
     remove_body ();
     raise e);

  (* Built as a list and converted once: mixing [| ... |] with [@] is a type
     error, since [@] concatenates lists. *)
  let argv =
    Array.of_list
      ([
         "curl";
         "-sS";
         "-N";
         "-i";
         "--connect-timeout";
         "30";
         "--speed-limit";
         "1";
         "--speed-time";
         string_of_int speed_time;
         "-X";
         "POST";
         "--data-binary";
         "@" ^ body_path;
       ]
      @ List.concat_map (fun (k, v) -> [ "-H"; k ^ ": " ^ v ]) headers
      @ [ url ])
  in

  let p = Proc_util.spawn ~prog:(find_curl ()) ~argv in
  (* Nothing is ever written to the child, so drop our end of its stdin at once. *)
  Proc_util.close_stdin p;
  let stderr_buf = Buffer.create 1024 in

  (* Debug affordance. When [MINI_PI_HTTP_DUMP] names a file, every line curl
     produces is appended to it verbatim -- headers included -- before anything
     is parsed. This exists because the parsed event stream cannot show a field
     the server never sent: when a run disagrees with a hand-written curl
     command, the only way to tell "the provider omitted it" from "we dropped
     it" is to look at the bytes. Off unless the variable is set. *)
  let dump_oc =
    match Sys.getenv_opt "MINI_PI_HTTP_DUMP" with
    | Some path when String.trim path <> "" -> (
        (* The request goes to <path>.request so a dumped run is self-contained:
           request and response side by side is what makes the comparison with a
           hand-written curl command possible. *)
        (try
           let oc = open_out_bin (path ^ ".request") in
           output_string oc body;
           close_out oc
         with _ -> ());
        try Some (open_out_bin path) with _ -> None)
    | _ -> None
  in

  let reader =
    Lwt_preemptive.detach
      (fun () ->
        (* [stderr_fd] is absent when the child was spawned with stderr merged
           into stdout; in that case there is simply nothing to drain. *)
        let err_thread =
          match p.stderr_fd with
          | Some fd ->
              Some
                (Thread.create
                   (fun () -> Buffer.add_string stderr_buf (Proc_util.read_all_fd fd))
                   ())
          | None -> None
        in
        let r = new_reader () in
        let dispatch actions =
          List.fold_left
            (fun acc action ->
              let* () = acc in
              match action with
              | `Headers meta -> on_headers meta
              | `Body line -> on_line line)
            Lwt.return_unit actions
        in
        Proc_util.iter_lines p.stdout_fd ~f:(fun line ->
            (match dump_oc with
            | Some oc ->
                output_string oc line;
                output_char oc '\n'
            | None -> ());
            Lwt_preemptive.run_in_main (fun () -> dispatch (reader_line r line)));
        (* Server closed mid-head, or with a head and no body at all: the caller
           is never left without a status. *)
        Lwt_preemptive.run_in_main (fun () -> dispatch (reader_finish r));
        ignore (Option.map Thread.join err_thread);
        (match dump_oc with
        | Some oc -> ( try close_out oc with _ -> ())
        | None -> ());
        let code = Proc_util.exit_code_of_status (Proc_util.wait p) in
        (* curl has exited, so it can no longer be reading the staged body: this
           is the one place where deleting it is guaranteed to be safe. *)
        remove_body ();
        code)
      ()
  in

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

  (* Backstop: if we leave through a cancellation or a timeout, the reader above
     may still be winding down, and a delete that loses that race leaves the file
     behind. Both removals are best effort. *)
  Lwt.finalize
    (fun () ->
      let* outcome =
        Lwt.pick
          [
            (let* code = reader in
             Lwt.return (`Done code));
            cancel_promise;
            timeout_promise;
          ]
      in
      match outcome with
      | `Cancelled ->
          Proc_util.kill p;
          Lwt.return `Cancelled
      | `Timeout ->
          Proc_util.kill p;
          Lwt.return `Timeout
      | `Done code ->
          if code <> 0 then
            let msg = String.trim (Buffer.contents stderr_buf) in
            Lwt.return
              (`Transport_error
                 (if msg = "" then Printf.sprintf "curl exited with code %d" code else msg))
          else Lwt.return `Ok)
    (fun () ->
      remove_body ();
      Lwt.return_unit)
