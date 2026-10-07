(* Port of ai/types.py
   Message / event / model / tool data model, plus the JSON encodings that must
   match pydantic's [model_dump(mode="json")] byte-for-byte, because the RPC
   protocol is consumed by the original TypeScript TUI. *)

type stop_reason = Stop | Length | Tool_use | Error | Aborted

let stop_reason_to_string = function
  | Stop -> "stop"
  | Length -> "length"
  | Tool_use -> "tool_use"
  | Error -> "error"
  | Aborted -> "aborted"

let stop_reason_of_string = function
  | "stop" -> Stop
  | "length" -> Length
  | "tool_calls" -> Tool_use
  | "tool_use" -> Tool_use
  | "error" -> Error
  | "aborted" -> Aborted
  | s -> failwith ("Unknown stop reason: " ^ s)

type usage = {
  input_tokens : int;
  output_tokens : int;
  cache_read : int;
  total_tokens : int;
}

let empty_usage = { input_tokens = 0; output_tokens = 0; cache_read = 0; total_tokens = 0 }

type tool_call = {
  id : string;
  name : string;
  arguments : Yojson.Safe.t; (* always `Assoc *)
}

type assistant_message = {
  content : string;
  tool_calls : tool_call list;
  thinking : string;
  thinking_signature : string option;
  stop_reason : stop_reason option;
  error_message : string option;
  usage : usage option;
}

type user_message = { content : string }

type tool_result_message = {
  tool_call_id : string;
  tool_name : string;
  content : string;
  is_error : bool;
}

type message =
  | User of user_message
  | Assistant of assistant_message
  | Tool_result of tool_result_message

let empty_assistant =
  {
    content = "";
    tool_calls = [];
    thinking = "";
    thinking_signature = None;
    stop_reason = None;
    error_message = None;
    usage = None;
  }

let assistant ~stop_reason ?error_message () =
  { empty_assistant with stop_reason = Some stop_reason; error_message }

let user content = User { content }

(* ------------------------------------------------------------------ *)
(* JSON encoding                                                       *)
(* ------------------------------------------------------------------ *)

let opt_string = function Some s -> `String s | None -> `Null

let usage_to_json (u : usage) : Yojson.Safe.t =
  `Assoc
    [
      ("input_tokens", `Int u.input_tokens);
      ("output_tokens", `Int u.output_tokens);
      ("cache_read", `Int u.cache_read);
      ("total_tokens", `Int u.total_tokens);
    ]

let tool_call_to_json (tc : tool_call) : Yojson.Safe.t =
  `Assoc
    [
      ("id", `String tc.id);
      ("name", `String tc.name);
      ("arguments", tc.arguments);
    ]

let assistant_to_json (m : assistant_message) : Yojson.Safe.t =
  `Assoc
    [
      ("role", `String "assistant");
      ("content", `String m.content);
      ("tool_calls", `List (List.map tool_call_to_json m.tool_calls));
      ("thinking", `String m.thinking);
      ("thinking_signature", opt_string m.thinking_signature);
      ( "stop_reason",
        match m.stop_reason with
        | Some s -> `String (stop_reason_to_string s)
        | None -> `Null );
      ("error_message", opt_string m.error_message);
      ("usage", match m.usage with Some u -> usage_to_json u | None -> `Null);
    ]

let to_json (m : message) : Yojson.Safe.t =
  match m with
  | User u -> `Assoc [ ("role", `String "user"); ("content", `String u.content) ]
  | Assistant a -> assistant_to_json a
  | Tool_result r ->
      `Assoc
        [
          ("role", `String "tool_result");
          ("tool_call_id", `String r.tool_call_id);
          ("tool_name", `String r.tool_name);
          ("content", `String r.content);
          ("is_error", `Bool r.is_error);
        ]

let message_role (m : message) : string =
  match m with User _ -> "user" | Assistant _ -> "assistant" | Tool_result _ -> "tool_result"

(* ------------------------------------------------------------------ *)
(* Decoding (used when loading session files / resume payloads)         *)
(* ------------------------------------------------------------------ *)

let member name = function
  | `Assoc l -> List.assoc_opt name l
  | _ -> None

let string_or name default j =
  match member name j with Some (`String s) -> s | _ -> default

let int_or name default j = match member name j with Some (`Int i) -> i | _ -> default

let opt_of member_name j =
  match member member_name j with Some (`String s) -> Some s | _ -> None

let usage_of_json j : usage =
  {
    input_tokens = int_or "input_tokens" 0 j;
    output_tokens = int_or "output_tokens" 0 j;
    cache_read = int_or "cache_read" 0 j;
    total_tokens = int_or "total_tokens" 0 j;
  }

let tool_call_of_json j : tool_call =
  {
    id = string_or "id" "" j;
    name = string_or "name" "" j;
    arguments =
      (match member "arguments" j with Some (`Assoc _ as a) -> a | _ -> `Assoc []);
  }

let assistant_of_json j : assistant_message =
  {
    content = string_or "content" "" j;
    tool_calls =
      (match member "tool_calls" j with
      | Some (`List l) -> List.map tool_call_of_json l
      | _ -> []);
    thinking = string_or "thinking" "" j;
    thinking_signature = opt_of "thinking_signature" j;
    stop_reason =
      (match opt_of "stop_reason" j with
      | Some s -> (try Some (stop_reason_of_string s) with _ -> None)
      | None -> None);
    error_message = opt_of "error_message" j;
    usage =
      (match member "usage" j with Some (`Assoc _ as u) -> Some (usage_of_json u) | _ -> None);
  }

let of_json (j : Yojson.Safe.t) : message =
  match member "role" j with
  | Some (`String "user") -> User { content = string_or "content" "" j }
  | Some (`String "assistant") -> Assistant (assistant_of_json j)
  | Some (`String "tool_result") ->
      Tool_result
        {
          tool_call_id = string_or "tool_call_id" "" j;
          tool_name = string_or "tool_name" "" j;
          content = string_or "content" "" j;
          is_error = (match member "is_error" j with Some (`Bool b) -> b | _ -> false);
        }
  | other -> failwith (Printf.sprintf "Unknown message role: %s" (Yojson.Safe.to_string (Option.value ~default:`Null other)))

(* ------------------------------------------------------------------ *)
(* LLM provider streaming events                                       *)
(* ------------------------------------------------------------------ *)

type stream_event =
  | Text_delta of string
  | Thinking_delta of string
  | Done of assistant_message

(* ------------------------------------------------------------------ *)
(* Model + tool descriptors                                            *)
(* ------------------------------------------------------------------ *)

type thinking_level = Off | Minimal | Low | Medium | High | Max

let thinking_level_to_string = function
  | Off -> "off"
  | Minimal -> "minimal"
  | Low -> "low"
  | Medium -> "medium"
  | High -> "high"
  | Max -> "max"

type openai_compat = {
  supports_usage_in_streaming : bool;
  max_tokens_field : string option;
}

let default_compat = { supports_usage_in_streaming = true; max_tokens_field = None }

type ai_model = {
  id : string;
  name : string;
  api : string;
  provider : string;
  base_url : string;
  reasoning : bool;
  thinking_level_map : (string * string option) list;
  context_window : int;
  max_tokens : int;
  compat : openai_compat option;
}

type tool = { name : string; description : string; parameters : Yojson.Safe.t }

type context = { system : string; messages : message list; tools : tool list }

type stream_options = {
  api_key : string option;
  signal : Ai_cancellation.t option;
  max_retries : int;
  timeout_seconds : float;
}

let default_stream_options =
  { api_key = None; signal = None; max_retries = 3; timeout_seconds = 300.0 }

type stream_fn =
  ai_model -> context -> stream_options -> (stream_event -> unit Lwt.t) -> unit Lwt.t
