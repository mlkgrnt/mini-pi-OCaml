(* Port of agent/tools.py *)

type t = {
  name : string;
  description : string;
  parameters : Yojson.Safe.t;
  execute : Yojson.Safe.t -> Ai_cancellation.t option -> string Lwt.t;
}

(* The provider only ever sees the descriptor, never the closure. *)
let to_ai_tool (t : t) : Ai_types.tool =
  { Ai_types.name = t.name; description = t.description; parameters = t.parameters }

let call (t : t) (arguments : Yojson.Safe.t) (signal : Ai_cancellation.t option) :
    string Lwt.t =
  try t.execute arguments signal
  with exn -> Lwt.return ("Error: " ^ Printexc.to_string exn)

let find (tools : t list) (name : string) : t option = List.find_opt (fun t -> t.name = name) tools
