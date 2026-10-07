(* Port of coding/session_runtime.py *)

open Lwt.Syntax

type t = {
  mutable session : Coding_session.t;
  mutable rebind_session : (Coding_session.t -> unit) option;
}

let create (session : Coding_session.t) : t = { session; rebind_session = None }

let set_rebind_session (t : t) (f : Coding_session.t -> unit) = t.rebind_session <- Some f

let replace (t : t) (csm : Coding_session_manager.t) : unit Lwt.t =
  Coding_session.cancel t.session;
  let config = { t.session.Coding_session.config with chat_session_manager = csm } in
  let* session = Coding_session.load config in
  t.session <- session;
  (match t.rebind_session with Some f -> f session | None -> ());
  Lwt.return_unit

let new_session (t : t) : unit Lwt.t =
  replace t
    (Coding_session_manager.new_session ~cwd:t.session.Coding_session.chat_session_manager.cwd ())

let switch_session (t : t) (session_id : string) : unit Lwt.t =
  match
    Coding_session_manager.search_session session_id
      t.session.Coding_session.chat_session_manager.cwd
  with
  | None -> Lwt.fail (Failure (Printf.sprintf "No session matching '%s'" session_id))
  | Some csm -> replace t csm
