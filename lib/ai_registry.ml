(* Port of ai/registry.py *)

type provider = {
  name : string;
  api_key : string option; (* literal key, or "$ENV_VAR" indirection *)
  models : Ai_types.ai_model list;
  streams : (string * Ai_types.stream_fn) list; (* api name -> stream fn *)
}

let providers : (string, provider) Hashtbl.t = Hashtbl.create 8
let mutex = Lwt_mutex.create ()

let register_inference_provider (p : provider) =
  if Hashtbl.mem providers p.name then failwith (p.name ^ " already exist");
  Hashtbl.replace providers p.name p

let get_provider name = Hashtbl.find_opt providers name

(* "provider:model_id" -> model *)
let split_model_ref (model_ref : string) : string * string =
  match String.index_opt model_ref ':' with
  | None -> failwith ("Invalid model ref (expected provider:model): " ^ model_ref)
  | Some i ->
      ( String.sub model_ref 0 i,
        String.sub model_ref (i + 1) (String.length model_ref - i - 1) )

let get_model (model_ref : string) : Ai_types.ai_model =
  let provider_name, model_id = split_model_ref model_ref in
  match get_provider provider_name with
  | None -> failwith (provider_name ^ " provider not found")
  | Some p -> (
      match List.find_opt (fun (m : Ai_types.ai_model) -> m.id = model_id) p.models with
      | Some m -> m
      | None -> failwith (model_id ^ " not found with provider " ^ provider_name))

let list_models () : Ai_types.ai_model list =
  Hashtbl.fold (fun _ p acc -> acc @ p.models) providers []

(* ------------------------------------------------------------------ *)
(* Credentials                                                         *)
(* ------------------------------------------------------------------ *)

(* Set by the coding layer to read ~/.mini-pi/auth.json *)
let credential_reader : (string -> string option) ref = ref (fun _ -> None)

let set_credential_reader f = credential_reader := f

(* A literal key, or "$NAME" to read one from the environment. Upstream only ever
   needs the single-variable form; the catalog adds one extension, "$A,$B", for
   vendors that accept the same key under several names -- Gemini, for instance,
   is reached with GOOGLE_API_KEY, GOOGLE_GENERATIVE_AI_API_KEY or GEMINI_API_KEY
   depending on which tool the user set it up with. The first variable that is
   set wins; a name that is unset is not the same as a name that is set to "",
   so an empty value keeps looking. *)
let resolve_api_key provider_name =
  match get_provider provider_name with
  | None -> failwith (provider_name ^ " provider not found")
  | Some p -> (
      match p.api_key with
      | None -> None
      | Some k ->
          if String.length k > 0 && k.[0] = '$' then
            let names = String.sub k 1 (String.length k - 1) in
            List.find_map
              (fun name ->
                match Sys.getenv_opt (String.trim name) with
                | Some v when String.trim v <> "" -> Some (String.trim v)
                | _ -> None)
              (String.split_on_char ',' names)
          else Some k)

let get_api_key provider =
  match !credential_reader provider with
  | Some k when String.trim k <> "" -> Some (String.trim k)
  | _ -> resolve_api_key provider

let stream (model : Ai_types.ai_model) (context : Ai_types.context)
    (options : Ai_types.stream_options) (emit : Ai_types.stream_event -> unit Lwt.t) :
    unit Lwt.t =
  match get_provider model.provider with
  | None -> failwith ("Unknown provider: " ^ model.provider)
  | Some p -> (
      match List.assoc_opt model.api p.streams with
      | None ->
          failwith
            (Printf.sprintf "Provider %s has no API implementation for %s" model.provider
               model.api)
      | Some fn ->
          let api_key = (match options.api_key with Some k -> Some k | None -> get_api_key model.provider) in
          fn model context { options with api_key } emit)

(* Kept for API parity with the Python registry; the mutex is available for
   callers that need to serialize provider registration at runtime. *)
let with_registry_lock f = Lwt_mutex.with_lock mutex f
