(* Port of coding/extensions/{types,api,runtime,loader}.py

   One deliberate divergence, documented in the README: the Python original
   imports third-party extension modules with importlib at runtime. An OCaml
   binary cannot host Python modules, so the *loading mechanism* is replaced:

     - bundled extensions (permission_gate, the fireworks provider) are compiled
       in and installed natively;
     - third-party extensions are described declaratively by a JSON descriptor
       in .mini-pi/extensions/bundled/, which can express the hook shapes that
       do not need arbitrary code (block a tool call, rewrite/absorb an input,
       emit a notification, expose a slash command).

   The runtime semantics — hook ordering, results, tool wrapping — are otherwise
   identical to the Python original. *)

open Lwt.Syntax

type select_fn = string -> string list -> string option Lwt.t

type ui = { select : select_fn; notify : string -> string -> unit }

let ui_confirm (u : ui) ~(title : string) ~(message : string) : bool Lwt.t =
  let* choice = u.select (Printf.sprintf "\n%s\n%s" title message) [ "Yes"; "No" ] in
  Lwt.return (choice = Some "Yes")

(* Environment handed to every hook handler. *)
type ctx = { cwd : string; mutable ui : ui option }

type tool_call_hook_result = {
  block : bool;
  arguments : Yojson.Safe.t option;
  reason : string option;
}

type tool_result_hook_result = { result : string option }

type input_action = Continue | Transform | Handled

type input_hook_result = { text : string option; action : input_action }

type hook =
  | On_tool_call of (string -> Yojson.Safe.t -> ctx -> tool_call_hook_result option Lwt.t)
  | On_tool_result of (string -> Yojson.Safe.t -> string -> ctx -> tool_result_hook_result option Lwt.t)
  | On_input of (string -> ctx -> input_hook_result option Lwt.t)

type command = { name : string; description : string; handler : string -> ctx -> unit Lwt.t }

type api = {
  extension_name : string;
  mutable tools : Agent_tools.t list;
  mutable commands : command list;
  mutable hooks : hook list;
}

let create_api name = { extension_name = name; tools = []; commands = []; hooks = [] }

let register_tool (a : api) (t : Agent_tools.t) = a.tools <- a.tools @ [ t ]
let register_command (a : api) (c : command) = a.commands <- a.commands @ [ c ]
let register_hook (a : api) (h : hook) = a.hooks <- a.hooks @ [ h ]

(* ------------------------------------------------------------------ *)
(* Runtime                                                             *)
(* ------------------------------------------------------------------ *)

type runtime = { mutable extensions : api list; context : ctx }

let create_runtime ~(cwd : string) = { extensions = []; context = { cwd; ui = None } }
let register_extension (r : runtime) (a : api) = r.extensions <- r.extensions @ [ a ]

(* The interface installs its own UI channel once it knows which mode it is in. *)
let set_ui (r : runtime) (u : ui option) = r.context.ui <- u
let get_ui (r : runtime) : ui option = r.context.ui

let handlers (r : runtime) (pred : hook -> bool) : hook list =
  List.concat_map (fun a -> List.filter pred a.hooks) r.extensions

let get_all_tools (r : runtime) : Agent_tools.t list =
  List.concat_map (fun a -> a.tools) r.extensions

let get_all_commands (r : runtime) : command list =
  List.concat_map (fun a -> a.commands) r.extensions

let get_command (r : runtime) (name : string) : command option =
  List.find_opt (fun c -> c.name = name) (get_all_commands r)

(* Wrap a tool so that tool_call hooks may block it or rewrite its arguments,
   and tool_result hooks may rewrite what the model sees. *)
let wrap_tool (r : runtime) (tool : Agent_tools.t) : Agent_tools.t =
  let original = tool.execute in
  let execute (arguments : Yojson.Safe.t) (signal : Ai_cancellation.t option) : string Lwt.t =
    let effective = ref arguments in
    let tool_call_hooks = handlers r (function On_tool_call _ -> true | _ -> false) in

    let rec apply_call_hooks = function
      | [] -> Lwt.return_none
      | On_tool_call f :: rest ->
          let* res = f tool.name !effective r.context in
          (match res with
          | Some r when r.block ->
              let reason = Option.value ~default:"Blocked by extension" r.reason in
              Lwt.return (Some (Printf.sprintf "Tool call blocked by extension: %s" reason))
          | Some r ->
              (match r.arguments with Some a -> effective := a | None -> ());
              apply_call_hooks rest
          | None -> apply_call_hooks rest)
      | _ :: rest -> apply_call_hooks rest
    in

    let* blocked = apply_call_hooks tool_call_hooks in
    match blocked with
    | Some msg -> Lwt.return msg
    | None ->
        let* result = original !effective signal in
        let effective_result = ref result in
        let tool_result_hooks = handlers r (function On_tool_result _ -> true | _ -> false) in

        let rec apply_result_hooks = function
          | [] -> Lwt.return_unit
          | On_tool_result f :: rest ->
              let* res = f tool.name !effective !effective_result r.context in
              (match res with
              | Some rr -> (match rr.result with Some s -> effective_result := s | None -> ())
              | None -> ());
              apply_result_hooks rest
          | _ :: rest -> apply_result_hooks rest
        in

        let* () = apply_result_hooks tool_result_hooks in
        Lwt.return !effective_result
  in
  { tool with Agent_tools.execute }

let run_input_hooks (r : runtime) (text : string) : input_hook_result Lwt.t =
  let current = ref text in
  let handled = ref false in
  let input_hooks = handlers r (function On_input _ -> true | _ -> false) in

  let rec go = function
    | [] -> Lwt.return_unit
    | On_input f :: rest ->
        let* res = f !current r.context in
        (match res with
        | Some res ->
            if res.action = Handled then (
              handled := true;
              Lwt.return_unit)
            else (
              (match (res.action, res.text) with
              | Transform, Some t -> current := t
              | _ -> ());
              go rest)
        | None -> go rest)
    | _ :: rest -> go rest
  in

  let* () = go input_hooks in
  if !handled then Lwt.return { text = None; action = Handled }
  else if !current <> text then Lwt.return { text = Some !current; action = Transform }
  else Lwt.return { text = None; action = Continue }

(* ------------------------------------------------------------------ *)
(* Declarative extension descriptors                                    *)
(* ------------------------------------------------------------------ *)

let load_descriptor (r : runtime) (path : string) : unit =
  match Yojson.Safe.from_string (Coding_tool_utils.read_file_text path) with
  | exception exn ->
      Printf.eprintf "[Warning] Failed to load extension %s: %s\n%!" (Filename.basename path)
        (Printexc.to_string exn)
  | json ->
      let name =
        match Ai_json.str_opt json "name" with
        | Some n -> n
        | None -> Filename.remove_extension (Filename.basename path)
      in
      let api = create_api name in

      (match Ai_json.list_opt json "commands" with
      | Some cmds ->
          List.iter
            (fun c ->
              match Ai_json.str_opt c "name" with
              | None -> ()
              | Some cname ->
                  let description = Ai_json.str c "description" "" in
                  let notify = Ai_json.str c "notify" "" in
                  register_command api
                    {
                      name = cname;
                      description;
                      handler =
                        (fun _args (ctx : ctx) ->
                          (match ctx.ui with
                          | Some ui when notify <> "" -> ui.notify notify "info"
                          | _ -> ());
                          Lwt.return_unit);
                    })
            cmds
      | None -> ());

      (match Ai_json.obj_opt json "hooks" with
      | Some hooks -> (
          (match Ai_json.list_opt hooks "tool_call" with
          | Some entries ->
              List.iter
                (fun e ->
                  let target = Ai_json.str e "tool" "" in
                  let block = match Ai_json.bool_opt e "block" with Some b -> b | None -> false in
                  let reason = Ai_json.str_opt e "reason" in
                  register_hook api
                    (On_tool_call
                       (fun tool_name _args _ctx ->
                         if tool_name = target then
                           Lwt.return (Some { block; arguments = None; reason })
                         else Lwt.return_none)))
                entries
          | None -> ());
          (match Ai_json.list_opt hooks "input" with
          | Some entries ->
              List.iter
                (fun e ->
                  let prefix = Ai_json.str e "prefix" "" in
                  let action =
                    match Ai_json.str e "action" "continue" with
                    | "handled" -> Handled
                    | "transform" -> Transform
                    | _ -> Continue
                  in
                  let replacement = Ai_json.str_opt e "text" in
                  let notify = Ai_json.str e "notify" "" in
                  register_hook api
                    (On_input
                       (fun text (ctx : ctx) ->
                         if prefix <> "" && String.starts_with ~prefix text then (
                           (match ctx.ui with
                           | Some ui when notify <> "" -> ui.notify notify "info"
                           | _ -> ());
                           Lwt.return (Some { text = replacement; action }))
                         else Lwt.return_none)))
                entries
          | None -> ()))
      | None -> ());

      register_extension r api

let load_extensions_from_dir (r : runtime) (dir : string) : unit =
  if Sys.file_exists dir && Sys.is_directory dir then
    let files = try Sys.readdir dir with _ -> [||] in
    Array.to_list files
    |> List.filter (fun f -> Filename.check_suffix f ".json")
    |> List.sort compare
    |> List.iter (fun f -> load_descriptor r (Filename.concat dir f))

(* ------------------------------------------------------------------ *)
(* Bundled extensions                                                   *)
(* ------------------------------------------------------------------ *)

(* Port of extensions/bundled/permission_gate.py *)
let install_permission_gate (r : runtime) : unit =
  let mode = ref (if Coding_tools.is_sandbox_available () then "auto" else "ask") in
  let api = create_api "permission_gate" in

  register_hook api
    (On_tool_call
       (fun tool_name (arguments : Yojson.Safe.t) (ctx : ctx) ->
         if tool_name <> "bash" then Lwt.return_none
         else if !mode <> "ask" then Lwt.return_none
         else
           match ctx.ui with
           | None ->
               Lwt.return
                 (Some
                    {
                      block = true;
                      arguments = None;
                      reason =
                        Some
                          "Bash command blocked: No sandbox. No channel exist for user confirmation";
                    })
           | Some ui ->
               let command = Ai_json.str arguments "command" "" in
               let* confirm = ui_confirm ui ~title:"Execute bash command" ~message:command in
               if confirm then Lwt.return_none
               else
                 Lwt.return
                   (Some
                      {
                        block = true;
                        arguments = None;
                        reason = Some "Bash command rejected by user";
                      })));

  register_command api
    {
      name = "permission";
      description = "View or set bash permission mode: /permission [ask|auto]";
      handler =
        (fun args (ctx : ctx) ->
          match ctx.ui with
          | None -> Lwt.return_unit
          | Some ui ->
              let arg = String.lowercase_ascii (String.trim args) in
              if arg = "" then (
                let sandbox_status =
                  if Coding_tools.is_sandbox_available () then "available" else "unavailable"
                in
                ui.notify
                  (Printf.sprintf "Current bash permission mode '%s' (sandbox: %s)" !mode sandbox_status)
                  "info";
                Lwt.return_unit)
              else if arg = "ask" then (
                mode := "ask";
                ui.notify "Bash permission mode set to ask" "info";
                Lwt.return_unit)
              else if arg = "auto" then (
                if not (Coding_tools.is_sandbox_available ()) then
                  ui.notify "Cannot set to 'auto' as no sandbox available." "info"
                else (
                  mode := "auto";
                  ui.notify "Bash permission mode set to auto" "info");
                Lwt.return_unit)
              else (
                ui.notify "Usage: /permission [ask|auto]" "info";
                Lwt.return_unit));
    };

  register_extension r api

(* Port of extensions/bundled/providers/fireworks.py *)
let install_fireworks_provider () : unit =
  let base_url = "https://api.fireworks.ai/inference/v1" in
  let provider_api = "openai-completions" in
  let provider_name = "fireworks" in
  let compat =
    { Ai_types.supports_usage_in_streaming = true; max_tokens_field = Some "max_tokens" }
  in
  let model id name context_window =
    {
      Ai_types.id = id;
      name;
      api = provider_api;
      provider = provider_name;
      base_url;
      reasoning = true;
      thinking_level_map = [];
      context_window;
      max_tokens = 64_000;
      compat = Some compat;
    }
  in
  if Ai_registry.get_provider provider_name = None then
    Ai_registry.register_inference_provider
      {
        Ai_registry.name = provider_name;
        api_key = Some "$FIREWORKS_API_KEY";
        streams = [ (provider_api, Ai_openai.stream_openai_completions) ];
        models =
          [
            model "accounts/fireworks/models/minimax-m3" "Minimax M3" 512_000;
            model "accounts/fireworks/models/glm-5p3-flash" "GLM 5.3 Flash" 1_040_000;
          ];
      }

(* The built-in provider catalog: ~54 vendors compiled in from lib/ai_catalog.ml,
   which tools/gen_providers.py generates from models.dev (plus, for the few
   vendors whose base URL the dataset does not carry, the URL their own docs
   state). It sits here rather than in a module of its own because upstream keeps
   its bundled providers in the extension directory too -- fireworks, directly
   above, is the one it ships.
 *
 * Every provider is registered with the same stream function, because the
 * catalog only contains endpoints that speak OpenAI Chat Completions. See
 * Ai_catalog_spec for why nothing else belongs in the list. *)
let install_catalog_providers () : unit =
  let api = "openai-completions" in
  let compat =
    { Ai_types.supports_usage_in_streaming = true; max_tokens_field = Some "max_tokens" }
  in
  List.iter
    (fun (p : Ai_catalog_spec.provider) ->
      (* A guard rather than an assumption: the bundled providers above may name
         the same vendor, and register_inference_provider refuses a duplicate. *)
      if Ai_registry.get_provider p.id = None then
        Ai_registry.register_inference_provider
          {
            Ai_registry.name = p.id;
            (* "$A,$B" = the first of these variables that is set (see
               Ai_registry.resolve_api_key). *)
            api_key = Some ("$" ^ String.concat "," p.env);
            streams = [ (api, Ai_openai.stream_openai_completions) ];
            models =
              List.map
                (fun (m : Ai_catalog_spec.model) ->
                  {
                    Ai_types.id = m.id;
                    name = m.label;
                    api;
                    provider = p.id;
                    base_url = p.base_url;
                    reasoning = m.reasoning;
                    thinking_level_map = [];
                    context_window = m.context_window;
                    max_tokens = m.max_tokens;
                    compat = Some compat;
                  })
                p.models;
          })
    Ai_catalog.providers

let install_bundled (r : runtime) : unit =
  install_fireworks_provider ();
  install_catalog_providers ();
  install_permission_gate r
