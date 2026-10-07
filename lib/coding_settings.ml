(* Port of coding/settings.py *)

type t = { default_model_ref : string option }

let settings_file_path () =
  Filename.concat (Filename.concat (Coding_auth.home_dir ()) ".mini-pi") "settings.json"

let load () : t =
  let path = settings_file_path () in
  if not (Sys.file_exists path) then { default_model_ref = None }
  else
    try
      match Yojson.Safe.from_string (Coding_tool_utils.read_file_text path) with
      | `Assoc _ as j -> { default_model_ref = Ai_json.str_opt j "default_model_ref" }
      | _ -> { default_model_ref = None }
    with _ -> { default_model_ref = None }

let save (s : t) =
  let path = settings_file_path () in
  Coding_tool_utils.mkdir_p (Filename.dirname path);
  let oc = open_out_bin path in
  output_string oc
    (Yojson.Safe.pretty_to_string
       (`Assoc
          [
            ( "default_model_ref",
              match s.default_model_ref with Some r -> `String r | None -> `Null );
          ]));
  close_out oc

let set_default_model (model_ref : string) =
  save { default_model_ref = Some model_ref }
