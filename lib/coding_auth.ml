(* Port of coding/auth.py *)

let home_dir () =
  match Sys.getenv_opt "HOME" with
  | Some h when h <> "" -> h
  | _ -> (match Sys.getenv_opt "USERPROFILE" with Some h when h <> "" -> h | _ -> Sys.getcwd ())

let auth_file_path () = Filename.concat (Filename.concat (home_dir ()) ".mini-pi") "auth.json"

let load_storage () : (string * string) list =
  let path = auth_file_path () in
  if not (Sys.file_exists path) then []
  else
    try
      match Yojson.Safe.from_string (Coding_tool_utils.read_file_text path) with
      | `Assoc l ->
          List.filter_map
            (function k, `String v -> Some (k, v) | _ -> None)
            l
      | _ -> []
    with _ -> []

let save_storage (storage : (string * string) list) =
  let path = auth_file_path () in
  Coding_tool_utils.mkdir_p (Filename.dirname path);
  let oc = open_out_bin path in
  output_string oc (Yojson.Safe.pretty_to_string (`Assoc (List.map (fun (k, v) -> (k, `String v)) storage)));
  close_out oc

let get_api_key_from_auth (provider : string) : string option =
  match List.assoc_opt provider (load_storage ()) with
  | Some cred when String.trim cred <> "" -> Some (String.trim cred)
  | _ -> None

let set_api_key_to_auth (provider : string) (key : string) =
  let storage = List.remove_assoc provider (load_storage ()) in
  save_storage ((provider, key) :: storage)

let remove_api_key_from_auth (provider : string) : bool =
  let storage = load_storage () in
  if List.mem_assoc provider storage then (
    save_storage (List.remove_assoc provider storage);
    true)
  else false
