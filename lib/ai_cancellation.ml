(* Port of ai/cancellation.py

   Python uses asyncio.Event so that a long running child process can be raced
   against the cancel signal without busy polling. We do the same with an Lwt
   promise that is resolved exactly once by [cancel]. *)

open Lwt.Syntax

type t = { cancelled : bool ref; promise : unit Lwt.t; wakener : unit Lwt.u }

let create () =
  let promise, wakener = Lwt.wait () in
  { cancelled = ref false; promise; wakener }

let cancel t =
  if not !(t.cancelled) then (
    t.cancelled := true;
    Lwt.wakeup_later t.wakener ())

let is_cancelled t = !(t.cancelled)

(* Resolves when the signal is cancelled, never otherwise. *)
let wait t = t.promise

(* Sleep for [seconds], but return early as soon as the signal fires.
   Returns [true] when the full duration elapsed, [false] when cancelled. *)
let abortable_sleep seconds signal =
  match signal with
  | None ->
      let* () = Lwt_unix.sleep seconds in
      Lwt.return_true
  | Some s ->
      if is_cancelled s then Lwt.return_false
      else
        Lwt.pick
          [
            (let* () = Lwt_unix.sleep seconds in
             Lwt.return_true);
            (let* () = wait s in
             Lwt.return_false);
          ]
