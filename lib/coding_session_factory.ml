(* Port of coding/session_factory.py

   Assembles everything a session needs: system prompt (base instructions plus
   AGENTS.md and any discovered skills), the four built-in tools, the extension
   runtime, and the model selection. *)

let default_system_prompt = "\nYou are helpful assistant. You have access to user filesystem.\n"

let build_session_config ?(cwd = "") ?(chat_session_manager : Coding_session_manager.t option)
    () : Coding_session.config Lwt.t =
  let cwd = if cwd = "" then Sys.getcwd () else cwd in

  let chat_session_manager =
    match chat_session_manager with
    | Some c -> c
    | None -> Coding_session_manager.new_session ~cwd ()
  in

  let context_files = Coding_context.discover_project_context ~cwd () in
  let skills = Coding_context.discover_skills ~cwd () in
  let dynamic_system_prompt =
    String.trim default_system_prompt
    ^ Coding_context.format_project_context context_files
    ^ Coding_context.format_skills skills
  in

  let tools = Coding_tools.create_all ~cwd in
  let extension_runtime = Coding_extensions.create_runtime ~cwd in

  (* Bundled extensions, then any project-local declarative descriptors. *)
  Coding_extensions.install_bundled extension_runtime;
  let extension_dir = Filename.concat (Filename.concat cwd ".mini-pi") "extensions/bundled" in
  Coding_tool_utils.mkdir_p extension_dir;
  Coding_extensions.load_extensions_from_dir extension_runtime extension_dir;

  (* Precedence: settings / auth storage beat the MODEL environment variable. *)
  let settings = Coding_settings.load () in
  let model_ref =
    match settings.default_model_ref with
    | Some r when r <> "" -> Some r
    | _ -> Sys.getenv_opt "MODEL"
  in

  let model_ref =
    match model_ref with
    | Some r -> r
    | None -> (
        match Ai_registry.list_models () with
        | first :: _ -> first.provider ^ ":" ^ first.id
        | [] -> failwith "No model registered.")
  in

  let ai_model = Ai_registry.get_model model_ref in
  Ai_registry.set_credential_reader Coding_auth.get_api_key_from_auth;

  Lwt.return
    {
      Coding_session.model = ai_model;
      system = dynamic_system_prompt;
      tools;
      chat_session_manager;
      compaction_settings = Coding_compaction.default_settings;
      extension_runtime = Some extension_runtime;
    }
