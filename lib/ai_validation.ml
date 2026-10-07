(* Port of ai/validation.py

   Python leans on jsonschema here. We implement the subset that actually
   matters for tool arguments: object shape, required keys, declared types, and
   the [_raw_arguments] sentinel that the stream parser plants when a provider
   hands us truncated or unparsable tool arguments. *)

open Ai_json

exception Validation_error of string

let type_matches json json_type =
  match (json_type, json) with
  | "string", `String _ -> true
  | "integer", `Int _ -> true
  | "number", (`Int _ | `Float _) -> true
  | "boolean", `Bool _ -> true
  | "object", `Assoc _ -> true
  | "array", `List _ -> true
  | "null", `Null -> true
  | _ -> false

let rec validate_schema ~path (schema : Yojson.Safe.t) (value : Yojson.Safe.t) =
  let fail msg = raise (Validation_error (Printf.sprintf "Validation failed at '%s': %s" path msg)) in
  match schema with
  | `Assoc _ -> (
      (* type *)
      (match str_opt schema "type" with
      | Some "object" -> (
          match value with
          | `Assoc fields ->
              (* required *)
              (match list_opt schema "required" with
              | Some reqs ->
                  List.iter
                    (function
                      | `String key ->
                          if not (List.mem_assoc key fields) then
                            fail (Printf.sprintf "'%s' is a required property" key)
                      | _ -> ())
                    reqs
              | None -> ());
              (* properties *)
              (* [obj_opt] hands back the whole [`Assoc] node, not the list it
                 wraps, so destructure it here. *)
              (match obj_opt schema "properties" with
              | Some (`Assoc props) ->
                  List.iter
                    (fun (key, sub) ->
                      match List.assoc_opt key fields with
                      | Some v -> validate_schema ~path:(path ^ "." ^ key) sub v
                      | None -> ())
                    props
              | None -> ())
          | _ -> fail "is not of type 'object'")
      | Some "array" -> (
          match value with
          | `List items -> (
              match member "items" schema with
              | Some itemschema ->
                  List.iteri (fun i v -> validate_schema ~path:(Printf.sprintf "%s.%d" path i) itemschema v) items
              | None -> ())
          | _ -> fail "is not of type 'array'")
      | Some t -> if not (type_matches value t) then fail ("is not of type '" ^ t ^ "'")
      | None -> ()))
  | `Bool true -> ()
  | `Bool false -> fail "schema is false"
  | _ -> ()

(* Mirrors [validate_tool_arguments] in the Python original. *)
let validate_tool_arguments (schema : Yojson.Safe.t) (arguments : Yojson.Safe.t) : unit =
  (match arguments with
  | `Assoc _ -> ()
  | _ -> raise (Validation_error "Arguments must be dictionary"));
  (match member "_raw_arguments" arguments with
  | Some raw ->
      raise
        (Validation_error
           ("Failed to parse tool call arguments as valid json: " ^ Yojson.Safe.to_string raw))
  | None -> ());
  validate_schema ~path:"root" schema arguments
