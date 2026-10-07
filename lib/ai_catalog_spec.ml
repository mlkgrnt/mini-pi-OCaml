(* Shapes for the built-in provider catalog.
 *
 * The catalog itself ([Ai_catalog]) is generated -- see tools/gen_providers.py --
 * so the types it needs live here, in a module with no dependencies. That keeps
 * the generated file free of logic and keeps [Ai_catalog] out of the way of
 * everything else in the library.
 *
 * Every provider in the catalog speaks OpenAI Chat Completions, because that is
 * the only wire format this port implements ([Ai_openai]). A provider whose API
 * has a different shape belongs in a new serializer, not in this list: adding it
 * here would mean shipping a provider that cannot work. *)

type model = {
  id : string;  (** the identifier to send in the request body *)
  label : string;  (** human-readable name, shown in the UI *)
  context_window : int;  (** input + output tokens, from the provider's metadata *)
  max_tokens : int;  (** maximum output tokens *)
  reasoning : bool;  (** whether the model is documented as a reasoning model *)
}

type provider = {
  id : string;  (** the name used in "provider:model" references *)
  label : string;
  base_url : string;
      (** Always without a trailing slash: the client appends "/chat/completions". *)
  env : string list;  (** environment variables searched for the API key, in order *)
  doc : string;  (** where the endpoint and model list come from *)
  models : model list;
}
