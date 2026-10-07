(* Port of ai/api/openai_completions/{serializer,parser,client}.py *)

open Lwt.Syntax
open Ai_json

(* ------------------------------------------------------------------ *)
(* Serializer                                                          *)
(* ------------------------------------------------------------------ *)

let tool_to_openai (t : Ai_types.tool) : Yojson.Safe.t =
  `Assoc
    [
      ("type", `String "function");
      ( "function",
        `Assoc
          [
            ("name", `String t.name);
            ("description", `String t.description);
            ("parameters", t.parameters);
          ] );
    ]

let tool_call_to_openai (tc : Ai_types.tool_call) : Yojson.Safe.t =
  `Assoc
    [
      ("id", `String tc.id);
      ("type", `String "function");
      ( "function",
        `Assoc
          [
            ("name", `String tc.name);
            ("arguments", `String (Yojson.Safe.to_string tc.arguments));
          ] );
    ]

let message_to_openai (m : Ai_types.message) : Yojson.Safe.t =
  match m with
  | Ai_types.User u -> `Assoc [ ("role", `String "user"); ("content", `String u.content) ]
  | Ai_types.Assistant a ->
      let base = [ ("role", `String "assistant"); ("content", `String a.content) ] in
      let with_thinking =
        if a.thinking = "" then base
        else
          base
          @ [
              ( (match a.thinking_signature with Some s -> s | None -> "reasoning_content"),
                `String a.thinking );
            ]
      in
      let with_calls =
        if List.length a.tool_calls = 0 then with_thinking
        else with_thinking @ [ ("tool_calls", `List (List.map tool_call_to_openai a.tool_calls)) ]
      in
      `Assoc with_calls
  | Ai_types.Tool_result r ->
      `Assoc
        [
          ("role", `String "tool");
          ("tool_call_id", `String r.tool_call_id);
          ("name", `String r.tool_name);
          ("content", `String r.content);
        ]

let build_chat_payload (model : Ai_types.ai_model) (system : string)
    (messages : Ai_types.message list) (tools : Ai_types.tool list) : Yojson.Safe.t =
  let messages = Ai_transform.transform_messages messages in
  let base =
    [
      ( "messages",
        `List
          (`Assoc [ ("role", `String "system"); ("content", `String system) ]
          :: List.map message_to_openai messages) );
      ("model", `String model.id);
      ("stream", `Bool true);
    ]
  in
  let with_tools =
    if List.length tools = 0 then base
    else base @ [ ("tools", `List (List.map tool_to_openai tools)) ]
  in
  let supports_usage =
    match model.compat with Some c -> c.supports_usage_in_streaming | None -> true
  in
  if supports_usage then
    `Assoc (with_tools @ [ ("stream_options", `Assoc [ ("include_usage", `Bool true) ]) ])
  else `Assoc with_tools

(* ------------------------------------------------------------------ *)
(* Streaming parser                                                    *)
(* ------------------------------------------------------------------ *)

type tool_call_builder = {
  mutable id : string;
  mutable name : string;
  mutable arguments_parts : string list;
}

type parser_state = {
  content_parts : string list ref;
  thinking_parts : string list ref;
  builders : (int, tool_call_builder) Hashtbl.t;
  mutable finish_reason : string option;
  mutable thinking_key : string option;
  mutable usage : Ai_types.usage option;
}

let new_parser () =
  {
    content_parts = ref [];
    thinking_parts = ref [];
    builders = Hashtbl.create 4;
    finish_reason = None;
    thinking_key = None;
    usage = None;
  }

let parse_arguments (text : string) : Yojson.Safe.t =
  if text = "" then `Assoc []
  else
    try match Yojson.Safe.from_string text with `Assoc _ as a -> a | _ -> `Assoc [ ("_raw_arguments", `String text) ]
    with _ -> `Assoc [ ("_raw_arguments", `String text) ]

let build_tool_call (b : tool_call_builder) (index : int) : Ai_types.tool_call =
  let arguments_text = String.concat "" (List.rev b.arguments_parts) in
  let tool_call_id = if b.id = "" then Printf.sprintf "tool-call-%d" index else b.id in
  {
    Ai_types.id = tool_call_id;
    name = (if b.name = "" then tool_call_id else b.name);
    arguments = parse_arguments arguments_text;
  }

let build_assistant_message (st : parser_state) ?stop_reason ?error_message () :
    Ai_types.assistant_message =
  let indexes = Hashtbl.fold (fun k _ acc -> k :: acc) st.builders [] |> List.sort compare in
  let tool_calls = List.map (fun i -> build_tool_call (Hashtbl.find st.builders i) i) indexes in
  {
    Ai_types.content = String.concat "" (List.rev !(st.content_parts));
    thinking = String.concat "" (List.rev !(st.thinking_parts));
    tool_calls;
    thinking_signature = st.thinking_key;
    stop_reason;
    error_message;
    usage = st.usage;
  }

let thinking_fields = [ "reasoning_content"; "reasoning"; "thinking"; "reasoning_text" ]

(* Consumers of a chunk: returns the incremental stream events. Raises on an
   error payload embedded in the stream, matching the Python original. *)
let feed (st : parser_state) (chunk : Yojson.Safe.t) : Ai_types.stream_event list =
  (match member "usage" chunk with
  | Some (`Assoc _ as u) ->
      let prompt_tokens = int_ u "prompt_tokens" 0 in
      let completion_tokens = int_ u "completion_tokens" 0 in
      let total_tokens = int_ u "total_tokens" 0 in
      let cached =
        match member "prompt_tokens_details" u with
        | Some d -> int_ d "cached_tokens" 0
        | None -> 0
      in
      st.usage <-
        Some
          {
            Ai_types.input_tokens = prompt_tokens;
            output_tokens = completion_tokens;
            cache_read = cached;
            total_tokens;
          }
  | _ -> ());

  (match member "error" chunk with
  | Some `Null | None -> ()
  | Some err ->
      let msg =
        match err with
        | `Assoc _ -> (
            match str_opt err "message" with Some m -> m | None -> Yojson.Safe.to_string err)
        | other -> Yojson.Safe.to_string other
      in
      raise (Failure ("Stream error: " ^ msg)));

  let choice =
    match list_opt chunk "choices" with
    | Some (c :: _) when (match c with `Assoc _ -> true | _ -> false) -> Some c
    | _ -> None
  in

  match choice with
  | None -> []
  | Some choice ->
      (match str_opt choice "finish_reason" with
      | Some fr -> st.finish_reason <- Some fr
      | None -> ());

      let delta = match obj_opt choice "delta" with Some d -> d | None -> `Assoc [] in
      let events = ref [] in

      (* Only the first thinking field that carries content is consumed, which
         mirrors the [break] in the Python original. *)
      let matched = ref false in
      List.iter
        (fun field ->
          if not !matched then
            match str_opt delta field with
            | Some t when t <> "" ->
                st.thinking_parts := t :: !(st.thinking_parts);
                if st.thinking_key = None then st.thinking_key <- Some field;
                events := Ai_types.Thinking_delta t :: !events;
                matched := true
            | _ -> ())
        thinking_fields;

      (match str_opt delta "content" with
      | Some c when c <> "" ->
          st.content_parts := c :: !(st.content_parts);
          events := Ai_types.Text_delta c :: !events
      | _ -> ());

      (match list_opt delta "tool_calls" with
      | Some deltas ->
          List.iter
            (fun d ->
              match d with
              | `Assoc _ ->
                  let index = int_ d "index" 0 in
                  let b =
                    match Hashtbl.find_opt st.builders index with
                    | Some b -> b
                    | None ->
                        let b = { id = ""; name = ""; arguments_parts = [] } in
                        Hashtbl.replace st.builders index b;
                        b
                  in
                  (match str_opt d "id" with Some id -> b.id <- id | None -> ());
                  (match obj_opt d "function" with
                  | Some fn ->
                      (match str_opt fn "name" with Some n -> b.name <- n | None -> ());
                      (match str_opt fn "arguments" with
                      | Some a -> b.arguments_parts <- a :: b.arguments_parts
                      | None -> ())
                  | None -> ())
              | _ -> ())
            deltas
      | None -> ());

      List.rev !events

let map_finish_reason (fr : string) : Ai_types.stop_reason =
  if fr = "tool_calls" then Ai_types.Tool_use else Ai_types.stop_reason_of_string fr

let finalize (st : parser_state) : Ai_types.stream_event =
  match st.finish_reason with
  | None -> raise (Failure "Stream ended without finish_reason")
  | Some "content_filter" -> raise (Failure "Provider finish_reason: content_filter")
  | Some ("stop" | "tool_calls" | "length" as fr) ->
      Ai_types.Done (build_assistant_message st ~stop_reason:(map_finish_reason fr) ())
  | Some other -> raise (Failure ("Provider finish_reason: " ^ other))

(* ------------------------------------------------------------------ *)
(* SSE framing                                                         *)
(* ------------------------------------------------------------------ *)

let parse_sse_line (line : string) : string option =
  let l = String.trim line in
  if l = "" || not (String.starts_with ~prefix:"data:" l) then None
  else Some (String.trim (String.sub l 5 (String.length l - 5)))

(* ------------------------------------------------------------------ *)
(* Client                                                              *)
(* ------------------------------------------------------------------ *)

let is_cancelled (options : Ai_types.stream_options) =
  match options.signal with Some s -> Ai_cancellation.is_cancelled s | None -> false

(* Streaming POST against an OpenAI-compatible /chat/completions endpoint, with
   the same retry policy as the Python client: retry on 408/409/429/5xx and on
   transport failures, but only if nothing has been emitted yet, because a
   partially streamed answer cannot be replayed to the caller. *)
let stream_openai_completions (model : Ai_types.ai_model) (context : Ai_types.context)
    (options : Ai_types.stream_options) (emit : Ai_types.stream_event -> unit Lwt.t) :
    unit Lwt.t =
  let payload = build_chat_payload model context.system context.messages context.tools in
  let body = Yojson.Safe.to_string payload in

  let calculate_delay ~attempt ~headers = Ai_retry.calculate_retry_delay ~headers ~attempt () in

  let rec run (attempt : int) : unit Lwt.t =
    let parser = new_parser () in
    let has_yielded = ref false in

    let done_aborted () =
      emit (Ai_types.Done (build_assistant_message parser ~stop_reason:Ai_types.Aborted ()))
    in
    let done_error msg =
      emit (Ai_types.Done (build_assistant_message parser ~stop_reason:Ai_types.Error ~error_message:msg ()))
    in

    let retry_after ~delay ~on_abort =
      if attempt < options.max_retries then
        let* slept_full = Ai_cancellation.abortable_sleep delay options.signal in
        if not slept_full then on_abort () else run (attempt + 1)
      else on_abort ()
    in

    if is_cancelled options then done_aborted ()
    else
      match options.api_key with
      | None | Some "" ->
          done_error (Printf.sprintf "API key is not set for provider: %s" model.provider)
      | Some key ->
          let url = model.base_url ^ "/chat/completions" in
          let headers =
            [ ("Authorization", "Bearer " ^ key); ("Content-Type", "application/json") ]
          in
          let status = ref 0 in
          let resp_headers = ref [] in
          let error_body = Buffer.create 512 in
          let is_error_status = ref false in
          let stopped = ref false in

          let on_headers (meta : Ai_http.meta) =
            status := meta.status;
            resp_headers := meta.headers;
            if meta.status >= 400 then is_error_status := true;
            Lwt.return_unit
          in

          let on_line (line : string) =
            if !stopped || !is_error_status then (
              if !is_error_status then (
                Buffer.add_string error_body line;
                Buffer.add_char error_body '\n');
              Lwt.return_unit)
            else
              match parse_sse_line line with
              | None -> Lwt.return_unit
              | Some "[DONE]" ->
                  stopped := true;
                  Lwt.return_unit
              | Some data -> (
                  match Yojson.Safe.from_string data with
                  | exception exn -> Lwt.fail exn
                  | chunk ->
                      let events = feed parser chunk in
                      List.fold_left
                        (fun acc ev ->
                          let* () = acc in
                          has_yielded := true;
                          emit ev)
                        Lwt.return_unit events)
          in

          let* outcome =
            Lwt.catch
              (fun () ->
                Ai_http.post_stream ~url ~headers ~body ~timeout:options.timeout_seconds
                  ~signal:options.signal ~on_headers ~on_line ())
              (fun exn -> Lwt.return (`Transport_error (Printexc.to_string exn)))
          in

          match outcome with
          | `Cancelled -> done_aborted ()
          | `Timeout ->
              let msg = Printf.sprintf "Request timed out after %gs" options.timeout_seconds in
              if (not !has_yielded) && attempt < options.max_retries then
                let delay = calculate_delay ~attempt ~headers:!resp_headers in
                retry_after ~delay ~on_abort:(fun () -> done_error msg)
              else done_error msg
          | `Transport_error msg ->
              let retryable =
                (not !has_yielded) && attempt < options.max_retries
                && Ai_retry.is_retryable_transport_error msg
              in
              if retryable then
                let delay = calculate_delay ~attempt ~headers:!resp_headers in
                retry_after ~delay ~on_abort:(fun () -> done_error msg)
              else done_error msg
          | `Ok ->
              if !is_error_status then (
                let text = String.trim (Buffer.contents error_body) in
                let retryable =
                  attempt < options.max_retries
                  && Ai_retry.is_retryable_status ~status_code:!status ~headers:!resp_headers
                in
                if retryable then
                  let delay =
                    try `Delay (calculate_delay ~attempt ~headers:!resp_headers)
                    with Failure msg -> `No_delay msg
                  in
                  match delay with
                  | `No_delay msg ->
                      done_error (Printf.sprintf "%s (%s)" text msg)
                  | `Delay d -> retry_after ~delay:d ~on_abort:(fun () -> done_error text)
                else done_error text)
              else
                Lwt.catch
                  (fun () -> emit (finalize parser))
                  (fun exn ->
                    let msg = Printexc.to_string exn in
                    if (not !has_yielded) && attempt < options.max_retries
                       && Ai_retry.is_retryable_transport_error msg
                    then
                      let delay = calculate_delay ~attempt ~headers:!resp_headers in
                      retry_after ~delay ~on_abort:(fun () -> done_error msg)
                    else done_error msg)

  in

  run 0
