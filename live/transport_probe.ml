(* Minimal transport probe.
 *
 *   OPENCODE_API_KEY=sk-... PROBE_MODE=<mode> dune exec live/transport_probe.exe
 *
 *   stdin   body via `--data-binary @-`, written to curl's stdin (what
 *           ai_http.post_stream does today)
 *   file    body via `--data-binary @<tempfile>`; every other argv entry is
 *           byte-identical to the stdin mode
 *
 * The live agent run stalls with curl alive and not one byte coming back. The
 * write itself succeeds (109/109 bytes, no exception) and the parent closes the
 * pipe, so the remaining suspects are the Windows handle plumbing in
 * Proc_util.spawn_full. Changing only the body delivery isolates exactly that:
 * if `file` streams and `stdin` does not, the child never receives a usable
 * stdin handle (and so never sees EOF, which `curl --data-binary @-` waits for
 * before it sends anything at all).
 *
 * It also mirrors post_stream's concurrency: `threads` mode runs the feeder and
 * the drainer on two Lwt_preemptive workers at once, as production does.
 *)

open Mini_pi

let endpoint = "https://opencode.ai/inference/openai/v1/chat/completions"

let body =
  {|{"model":"deepseek-v4.1-flash","messages":[{"role":"user","content":"Say hi"}],"max_tokens":40,"stream":true}|}

(* Identical to ai_http.post_stream's argv apart from the body source. *)
let argv ~key ~(data_arg : string) =
  [|
    "curl"; "-sS"; "-N"; "-i"; "--connect-timeout"; "30"; "--speed-limit"; "1";
    "--speed-time"; "300"; "-X"; "POST"; "--data-binary"; data_arg; "-H";
    ("Authorization: Bearer " ^ key); "-H"; "Content-Type: application/json"; endpoint;
  |]

let t0 = ref 0.0
let stamp () = Unix.gettimeofday () -. !t0
let log fmt = Printf.ksprintf (fun s -> Printf.printf "  %6.2fs %s\n%!" (stamp ()) s) fmt

let count_lines = ref 0

(* Deliberately does NOT swallow errors, unlike Proc_util.write_all whose
   `with _ -> ()` makes a failed write indistinguishable from a successful one. *)
let write_verbose (p : Proc_util.t) data =
  let len = String.length data in
  let buf = Bytes.of_string data in
  let written = ref 0 in
  (try
     while !written < len do
       let n = Unix.write p.stdin_fd buf !written (min 65536 (len - !written)) in
       if n <= 0 then (
         log "write returned %d -- stopping" n;
         raise Exit);
       written := !written + n
     done;
     log "wrote %d/%d bytes" !written len
   with e -> log "WRITE FAILED after %d/%d bytes: %s" !written len (Printexc.to_string e));
  try
    Unix.close p.stdin_fd;
    log "stdin closed"
  with e -> log "STDIN CLOSE FAILED: %s" (Printexc.to_string e)

let run ~mode ~key =
  Printf.printf "\n== mode=%s ==\n%!" mode;
  count_lines := 0;
  t0 := Unix.gettimeofday ();

  (* For `file`, stage the body on disk and let curl read it from there. *)
  let tmp =
    if mode = "file" then (
      let path =
        Filename.concat (Filename.get_temp_dir_name ())
          (Printf.sprintf "minipi_probe_%d.json" (Random.int 1_000_000))
      in
      let oc = open_out_bin path in
      output_string oc body;
      close_out oc;
      log "staged %d bytes at %s" (String.length body) path;
      Some path)
    else None
  in

  let data_arg = match tmp with Some p -> "@" ^ p | None -> "@-" in
  let p = Proc_util.spawn ~prog:"curl" ~argv:(argv ~key ~data_arg) in
  log "spawned curl pid=%d (data_arg=%S)" p.pid data_arg;

  let drain () =
    Proc_util.iter_lines p.stdout_fd ~f:(fun line ->
        incr count_lines;
        let n = String.length line in
        log "line %d: %s" !count_lines (String.sub line 0 (min 100 n)));
    log "stdout drained (%d lines)" !count_lines;
    let st = Proc_util.wait p in
    log "curl reaped -> exit %d" (Proc_util.exit_code_of_status st)
  in

  if mode = "file" then drain ()
  else if mode = "stdin" then (
    write_verbose p body;
    drain ())
  else if mode = "threads" then (
    let producer = Lwt_preemptive.detach (fun () -> write_verbose p body) () in
    let reader = Lwt_preemptive.detach drain () in
    Lwt_main.run (Lwt.join [ producer; reader ]))
  else (prerr_endline ("unknown mode: " ^ mode); exit 2);

  (match tmp with Some path -> (try Sys.remove path with _ -> ()) | None -> ());
  !count_lines > 0

let () =
  let key = match Sys.getenv_opt "OPENCODE_API_KEY" with
    | Some k when String.trim k <> "" -> String.trim k
    | _ -> prerr_endline "set OPENCODE_API_KEY"; exit 2
  in
  let mode = match Sys.getenv_opt "PROBE_MODE" with Some m -> m | None -> "stdin" in
  Printf.printf "transport probe\n%!";
  (* No in-process watchdog: Unix.fork is not available on Windows. Run one mode
     per invocation and cap it from the shell. *)
  let got_data = run ~mode ~key in
  Printf.printf "\n%s\n" (if got_data then "PASSED (data came back)" else "FAILED (no data)");
  exit (if got_data then 0 else 1)
