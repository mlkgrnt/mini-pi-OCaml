(* Small helpers shared by every module that touches untrusted JSON coming from
   a model provider. Deliberately total: nothing here raises on a malformed
   payload, because providers are inconsistent about optional fields. *)

let member name = function `Assoc l -> List.assoc_opt name l | _ -> None

let str_opt j name = match member name j with Some (`String s) -> Some s | _ -> None
let int_opt j name = match member name j with Some (`Int i) -> Some i | _ -> None
let bool_opt j name = match member name j with Some (`Bool b) -> Some b | _ -> None

let str j name default = Option.value ~default (str_opt j name)
let int_ j name default = Option.value ~default (int_opt j name)

let obj_opt j name = match member name j with Some (`Assoc _ as a) -> Some a | _ -> None
let list_opt j name = match member name j with Some (`List l) -> Some l | _ -> None

let assoc_of_json default = function `Assoc _ as a -> a | _ -> default

(* Pretty compact one-line rendering, matching json.dumps defaults closely
   enough for anything that lands in a prompt. *)
let to_string (j : Yojson.Safe.t) : string = Yojson.Safe.to_string j

(* Python's json.dumps default puts a space after ':' and ','. The provider
   payload we re-serialize for tool calls does not need to match byte for byte,
   but keeping it stable makes the transcript readable. *)
let dump (j : Yojson.Safe.t) : string = Yojson.Safe.to_string j
