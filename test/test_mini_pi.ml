(* Verification suite for the OCaml port.

   Deliberately offline: instead of hitting a real provider, the agent loop is
   driven by a scripted [stream_fn]. That makes the assertions about event
   ordering, tool dispatch, session persistence and compaction deterministic,
   and it means the suite runs anywhere. *)

(* The library is wrapped, so its modules live under [Mini_pi]; open it once
   rather than prefixing every reference below. *)
open Mini_pi

let failures = ref 0

let check name cond =
  if cond then Printf.printf "  ok    %s\n" name
  else (
    incr failures;
    Printf.printf "  FAIL  %s\n" name)

(* [check] for the cases where the failure is a list, or a count, and saying
   which is far more useful than saying that something is wrong. *)
let check_msg name cond detail =
  if cond then Printf.printf "  ok    %s\n" name
  else (
    incr failures;
    Printf.printf "  FAIL  %s\n        %s\n" name detail)

let check_eq name a b =
  if a = b then Printf.printf "  ok    %s\n" name
  else (
    incr failures;
    Printf.printf "  FAIL  %s\n        got:  %s\n        want: %s\n" name a b)

let section s = Printf.printf "\n== %s ==\n" s

(* ------------------------------------------------------------------ *)
(* Helpers                                                             *)
(* ------------------------------------------------------------------ *)

let rec rm_rf path =
  if Sys.file_exists path then
    if Sys.is_directory path then (
      Array.iter (fun c -> rm_rf (Filename.concat path c)) (try Sys.readdir path with _ -> [||]);
      (try Unix.rmdir path with _ -> ()))
    else try Unix.unlink path with _ -> ()

let read_file p = Coding_tool_utils.read_file_text p

let temp_dir prefix =
  let base = Filename.concat (Filename.get_temp_dir_name ()) (prefix ^ "_" ^ string_of_int (Random.int 1_000_000)) in
  rm_rf base;
  Coding_tool_utils.mkdir_p base;
  base

(* ------------------------------------------------------------------ *)
(* 1. JSON encoding, which is the contract with the TUI                *)
(* ------------------------------------------------------------------ *)

let test_json_encoding () =
  section "JSON encoding";
  let usage = { Ai_types.input_tokens = 10; output_tokens = 2; cache_read = 1; total_tokens = 12 } in
  let a =
    {
      Ai_types.content = "hi";
      tool_calls = [ { Ai_types.id = "c1"; name = "read"; arguments = `Assoc [ ("path", `String "a") ] } ];
      thinking = "why";
      thinking_signature = Some "reasoning_content";
      stop_reason = Some Ai_types.Tool_use;
      error_message = None;
      usage = Some usage;
    }
  in
  let j = Ai_types.assistant_to_json a in
  check_eq "assistant message keys and order"
    (Yojson.Safe.to_string j)
    {|{"role":"assistant","content":"hi","tool_calls":[{"id":"c1","name":"read","arguments":{"path":"a"}}],"thinking":"why","thinking_signature":"reasoning_content","stop_reason":"tool_use","error_message":null,"usage":{"input_tokens":10,"output_tokens":2,"cache_read":1,"total_tokens":12}}|};

  (* Round-trip through the same shape the session file stores. *)
  let back = Ai_types.assistant_of_json j in
  check "assistant message round-trips" (back = a);

  let tr = Ai_types.to_json (Ai_types.Tool_result { tool_call_id = "c1"; tool_name = "read"; content = "x"; is_error = true }) in
  check_eq "tool result message"
    (Yojson.Safe.to_string tr)
    {|{"role":"tool_result","tool_call_id":"c1","tool_name":"read","content":"x","is_error":true}|};

  let um = Ai_types.to_json (Ai_types.User { content = "hello" }) in
  check_eq "user message" (Yojson.Safe.to_string um) {|{"role":"user","content":"hello"}|};

  (* Session events, exactly as the TUI's types/events.ts expects them. *)
  let ev = Coding_events.to_json (Coding_events.Agent (Agent_events.Message_update (Agent_events.Text_delta "ab"))) in
  check_eq "message_update / text_delta"
    (Yojson.Safe.to_string ev)
    {|{"type":"message_update","assistant_message_event":{"type":"text_delta","delta":"ab"}}|};

  let ev = Coding_events.to_json (Coding_events.Agent (Agent_events.Tool_execution_start { tool_call_id = "i"; tool_name = "bash"; arguments = `Assoc [] })) in
  check_eq "tool_execution_start"
    (Yojson.Safe.to_string ev)
    {|{"type":"tool_execution_start","tool_call_id":"i","tool_name":"bash","arguments":{}}|};

  let ev = Coding_events.to_json (Coding_events.Compaction_end { result = None; error_message = Some "boom" }) in
  check_eq "compaction_end nulls"
    (Yojson.Safe.to_string ev)
    {|{"type":"compaction_end","result":null,"error_message":"boom"}|};

  let ev = Coding_events.to_json (Coding_events.Agent Agent_events.Agent_start) in
  check_eq "agent_start" (Yojson.Safe.to_string ev) {|{"type":"agent_start"}|};

  let cs = Coding_messages.to_json (Coding_messages.Compaction_summary "S") in
  check_eq "compaction summary message" (Yojson.Safe.to_string cs) {|{"role":"compaction_summary","summary":"S"}|};

  let llm = Coding_messages.to_llm (Coding_messages.Compaction_summary "S") in
  match llm with
  | Ai_types.User u ->
      check "summary becomes a user message with <summary> tags"
        (String.length u.content > 0 && Coding_tool_utils.count_occurrences u.content "<summary>" = 1)
  | _ -> check "summary becomes a user message" false

(* ------------------------------------------------------------------ *)
(* 1b. The OpenAI SSE stream, parsed off the wire                       *)
(* ------------------------------------------------------------------ *)

(* Section 1 checks what the port *emits*. Nothing so far checked what it
   *understands*: every other test hands the agent loop an already-parsed event
   list, so the JSON -> event layer in ai_openai.ml -- the part that has to cope
   with a real provider's framing -- was never exercised. That is exactly the
   layer a live run depends on, and the reason the offline suite could pass
   while a real stream still went wrong.

   The frames below are verbatim OpenAI-compatible chunks, deliberately split
   the way a provider splits them: the tool arguments arrive in two pieces,
   which is the case a naive parser gets wrong. *)
let test_openai_stream_parser () =
  section "OpenAI SSE stream parsing";

  let frames =
    [
      {|{"choices":[{"delta":{"reasoning_content":"I should "},"index":0}]}|};
      {|{"choices":[{"delta":{"reasoning_content":"write a file."},"index":0}]}|};
      {|{"choices":[{"delta":{"content":"ok\n"},"index":0}]}|};
      {|{"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"write","arguments":"{\"path\":\"a"}}]},"index":0}]}|};
      {|{"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":".txt\"}"}}]},"index":0}]}|};
      {|{"choices":[{"delta":{},"finish_reason":"tool_calls","index":0}],"usage":{"prompt_tokens":11,"completion_tokens":7,"total_tokens":18,"prompt_tokens_details":{"cached_tokens":3}}}|};
    ]
  in

  (* Frames wrapped in the framing a real endpoint interleaves: blank lines
     between events, a comment/keepalive line, and the terminating sentinel. *)
  let stream =
    String.concat "\n"
      ([ ": keepalive"; "" ] @ List.map (fun f -> "data: " ^ f) frames @ [ ""; "data: [DONE]"; "" ])
  in

  let parser = Ai_openai.new_parser () in
  let text = Buffer.create 64 in
  let thinking = Buffer.create 64 in
  let saw_done = ref false in
  let dropped = ref 0 in

  List.iter
    (fun line ->
      let trimmed = String.trim line in
      match Ai_openai.parse_sse_line line with
      | None ->
          (* Blank lines separate events and ": ..." lines are comments, so both
             must be skipped silently. Anything else would be a framing bug. *)
          if trimmed <> "" && not (String.starts_with ~prefix:":" trimmed) then incr dropped
      | Some "[DONE]" -> saw_done := true
      | Some payload ->
          List.iter
            (function
              | Ai_types.Text_delta d -> Buffer.add_string text d
              | Ai_types.Thinking_delta d -> Buffer.add_string thinking d
              | Ai_types.Done _ -> incr dropped)
            (Ai_openai.feed parser (Yojson.Safe.from_string payload)))
    (String.split_on_char '\n' stream);

  check_eq "reasoning_content becomes a thinking delta" (Buffer.contents thinking)
    "I should write a file.";
  check_eq "content deltas accumulate in order" (Buffer.contents text) "ok\n";
  check "the [DONE] sentinel is recognised" !saw_done;
  check_eq "no frame was dropped or misframed" (string_of_int !dropped) "0";

  let finished =
    match Ai_openai.finalize parser with
    | Ai_types.Done a -> a
    | _ -> failwith "finalize must produce Done"
  in
  check_eq "finish_reason tool_calls maps to stop_reason tool_use"
    (match finished.stop_reason with Some s -> Ai_types.stop_reason_to_string s | None -> "none")
    "tool_use";
  check_eq "exactly one tool call was assembled"
    (string_of_int (List.length finished.tool_calls)) "1";
  (match finished.tool_calls with
  | [ tc ] ->
      check_eq "tool call id" tc.Ai_types.id "call_1";
      check_eq "tool call name" tc.Ai_types.name "write";
      check_eq "arguments split across deltas are reassembled"
        (Yojson.Safe.to_string tc.Ai_types.arguments)
        {|{"path":"a.txt"}|}
  | _ -> check "the tool call is well formed" false);
  check_eq "thinking is joined in stream order" finished.thinking "I should write a file.";
  check_eq "thinking_signature records the field the provider used"
    (match finished.thinking_signature with Some s -> s | None -> "none")
    "reasoning_content";
  (match finished.usage with
  | Some u ->
      check_eq "usage total is read" (string_of_int u.Ai_types.total_tokens) "18";
      check_eq "cached prompt tokens are read" (string_of_int u.Ai_types.cache_read) "3"
  | None -> check "usage is present" false);

  (* Truncated arguments must not throw: they are kept verbatim under the
     sentinel so the tool layer can report them instead of losing the call. *)
  let p2 = Ai_openai.new_parser () in
  ignore
    (Ai_openai.feed p2
       (Yojson.Safe.from_string
          {|{"choices":[{"delta":{"tool_calls":[{"index":0,"id":"c2","function":{"name":"bash","arguments":"{\"command\":"}}]},"index":0}]}|}));
  ignore
    (Ai_openai.feed p2
       (Yojson.Safe.from_string {|{"choices":[{"delta":{},"finish_reason":"tool_calls","index":0}]}|}));
  (match Ai_openai.finalize p2 with
  | Ai_types.Done a -> (
      match a.tool_calls with
      | [ tc ] ->
          check "unparseable arguments are kept under _raw_arguments"
            (Coding_tool_utils.count_occurrences (Yojson.Safe.to_string tc.Ai_types.arguments) "_raw_arguments" = 1)
      | _ -> check "one tool call survives truncation" false)
  | _ -> check "Done" false);

  (* A stream that stops without a finish_reason is an error, not empty output. *)
  let p3 = Ai_openai.new_parser () in
  check "finalize refuses a stream with no finish_reason"
    (try ignore (Ai_openai.finalize p3); false with _ -> true);

  (* content_filter must surface as a failure rather than a silent empty reply. *)
  let p4 = Ai_openai.new_parser () in
  ignore
    (Ai_openai.feed p4
       (Yojson.Safe.from_string {|{"choices":[{"delta":{},"finish_reason":"content_filter","index":0}]}|}));
  check "content_filter is reported as an error"
    (try ignore (Ai_openai.finalize p4); false with _ -> true);

  (* An error payload embedded mid-stream must raise, not be ignored. *)
  let p5 = Ai_openai.new_parser () in
  check "an error frame inside the stream raises"
    (try
       ignore (Ai_openai.feed p5 (Yojson.Safe.from_string {|{"error":{"message":"boom"}}|}));
       false
     with _ -> true)

(* ------------------------------------------------------------------ *)
(* 1c. Response head parsing                                            *)
(* ------------------------------------------------------------------ *)

(* The head reader is pulled out of the transport so this can be tested without
   a socket, because the case that matters is the one that is awkward to
   reproduce live: [curl -i] behind a proxy prints the proxy's CONNECT reply and
   then the origin's real response, and taking the first status for the real one
   silently turns a 401 into a 200. *)
let test_http_head_parsing () =
  section "HTTP response head parsing";

  (* The [let] is load-bearing. OCaml evaluates the operands of [@]
     right-to-left, so writing this as one expression runs [reader_finish] --
     which drains whatever head is pending -- *before* any line is fed, and the
     reader then looks as though it never parsed the status line at all. *)
  let run lines =
    let r = Ai_http.new_reader () in
    let from_lines = List.concat_map (Ai_http.reader_line r) lines in
    from_lines @ Ai_http.reader_finish r
  in
  let headers actions = List.filter_map (function `Headers m -> Some m | `Body _ -> None) actions in
  let bodies actions = List.filter_map (function `Body l -> Some l | `Headers _ -> None) actions in
  let status actions =
    match headers actions with [ m ] -> string_of_int m.Ai_http.status | _ -> "not-exactly-one-head"
  in

  (* A plain, direct response. *)
  let a =
    run [ "HTTP/1.1 200 OK"; "Content-Type: text/event-stream"; ""; "data: a"; "data: [DONE]" ]
  in
  check_eq "direct response status" (status a) "200";
  check_eq "body lines pass through" (String.concat "|" (bodies a)) "data: a|data: [DONE]";
  check "the head is announced before the first body line"
    (match a with `Headers _ :: `Body _ :: _ -> true | _ -> false);

  (* The proxy case: the CONNECT reply must not become the reported status, and
     its headers must not leak into the ones the caller sees. *)
  let a =
    run
      [
        "HTTP/1.1 200 Connection Established";
        "Proxy-Agent: whatever";
        "";
        "HTTP/1.1 401 Unauthorized";
        "Content-Type: application/json";
        "Retry-After: 7";
        "";
        {|{"error":"nope"}|};
      ]
  in
  check_eq "proxy CONNECT is not mistaken for the response" (status a) "401";
  check_eq "only the origin's body is passed through" (String.concat "|" (bodies a)) {|{"error":"nope"}|};
  (match headers a with
  | [ m ] ->
      let find k = List.assoc_opt k m.Ai_http.headers in
      check "the origin's headers are kept" (find "Retry-After" = Some "7");
      check "the proxy's headers are dropped" (find "Proxy-Agent" = None)
  | _ -> check "exactly one head was delivered" false);

  (* 100 Continue is an intermediate response, not the answer. *)
  let a =
    run
      [
        "HTTP/1.1 100 Continue";
        "";
        "HTTP/1.1 200 OK";
        "Content-Type: text/event-stream";
        "";
        "data: x";
      ]
  in
  check_eq "100 Continue is skipped" (status a) "200";

  (* A head with no body still has to report its status. *)
  let a = run [ "HTTP/1.1 429 Too Many Requests"; "Retry-After: 3"; "" ] in
  check_eq "a body-less response still reports its status" (status a) "429";
  (match headers a with
  | [ m ] -> check "its headers survive" (List.assoc_opt "Retry-After" m.Ai_http.headers = Some "3")
  | _ -> check "exactly one head was delivered" false);

  (* A connection cut off mid-head must not lose the status line. *)
  let a = run [ "HTTP/1.1 500 Internal Server Error"; "Content-Type: application/json" ] in
  check_eq "a truncated head still reports its status" (status a) "500";

  (* And nothing at all must not report a head twice. *)
  let a = run [] in
  check_eq "an empty response delivers exactly one head" (string_of_int (List.length (headers a))) "1"

(* ------------------------------------------------------------------ *)
(* 1d. The generated provider catalog                                   *)
(* ------------------------------------------------------------------ *)

(* Ai_catalog is generated (tools/gen_providers.py), and generated data rots
   quietly: a provider whose base URL keeps a trailing slash, a model with a zero
   context window, two entries with the same id. None of that is visible by
   reading the file, so the invariants are asserted here instead. *)
let test_catalog () =
  section "Provider catalog";

  let providers = Ai_catalog.providers in
  let models = List.concat_map (fun (p : Ai_catalog_spec.provider) -> p.models) providers in
  let ids = List.map (fun (p : Ai_catalog_spec.provider) -> p.id) providers in

  check_msg "the catalog is not empty" (List.length providers >= 40)
    (Printf.sprintf "providers=%d" (List.length providers));
  check_msg "it carries a useful number of models" (List.length models >= 300)
    (Printf.sprintf "models=%d" (List.length models));

  (* The mainstream vendors have to be there, or the catalog is not doing its job. *)
  let wanted =
    [ "openai"; "anthropic"; "google"; "xai"; "groq"; "mistral"; "deepseek";
      "cerebras"; "togetherai"; "deepinfra"; "openrouter"; "moonshotai";
      "zhipuai"; "alibaba"; "ollama-cloud"; "lmstudio" ]
  in
  let missing = List.filter (fun w -> not (List.mem w ids)) wanted in
  check_msg "the mainstream vendors are present" (missing = [])
    (Printf.sprintf "missing: %s" (String.concat ", " missing));

  let dup_id =
    List.sort_uniq compare ids |> List.filter (fun id -> List.length (List.filter (( = ) id) ids) > 1)
  in
  check "no provider id is registered twice" (dup_id = []);

  let no_env = List.filter (fun (p : Ai_catalog_spec.provider) -> p.env = []) providers in
  check_msg "every provider knows where to read a key from" (no_env = [])
    (Printf.sprintf "without env: %s"
       (String.concat ", " (List.map (fun (p : Ai_catalog_spec.provider) -> p.id) no_env)));

  (* The client builds "<base_url>/chat/completions", so a trailing slash would
     produce a double slash. The generator strips them; this is the guard that
     keeps it doing so. *)
  let bad_url =
    List.filter
      (fun (p : Ai_catalog_spec.provider) ->
        not (String.starts_with ~prefix:"http" p.base_url)
        || String.ends_with ~suffix:"/" p.base_url)
      providers
  in
  check_msg "every base url is a plain http(s) prefix without a trailing slash" (bad_url = [])
    (String.concat ", "
       (List.map (fun (p : Ai_catalog_spec.provider) -> p.id ^ "=" ^ p.base_url) bad_url));

  let bad_model =
    List.filter
      (fun (m : Ai_catalog_spec.model) -> m.id = "" || m.context_window <= 0 || m.max_tokens <= 0)
      models
  in
  check_msg "every model has an id and positive limits" (bad_model = [])
    (String.concat ", " (List.map (fun (m : Ai_catalog_spec.model) -> m.id) bad_model));

  (* Compaction reads context_window and overflow detection reads max_tokens, so
     a model claiming more output than it has window would be a quiet
     inconsistency rather than a loud one. *)
  let over = List.filter (fun (m : Ai_catalog_spec.model) -> m.max_tokens > m.context_window) models in
  check_msg "no model claims more output than its context window" (over = [])
    (String.concat ", " (List.map (fun (m : Ai_catalog_spec.model) -> m.id) over));

  let dup_models =
    List.filter
      (fun (p : Ai_catalog_spec.provider) ->
        let ms = List.map (fun (m : Ai_catalog_spec.model) -> m.id) p.models in
        List.length ms <> List.length (List.sort_uniq compare ms))
      providers
  in
  check_msg "no provider lists the same model twice" (dup_models = [])
    (String.concat ", " (List.map (fun (p : Ai_catalog_spec.provider) -> p.id) dup_models));

  (* The endpoints that were taken from documentation rather than the dataset are
     the ones worth pinning, since nothing else would notice a typo. *)
  let base_url_of id = List.assoc_opt id (List.map (fun (p : Ai_catalog_spec.provider) -> (p.id, p.base_url)) providers) in
  check_eq "openai base url" (Option.value ~default:"-" (base_url_of "openai")) "https://api.openai.com/v1";
  check_eq "anthropic base url" (Option.value ~default:"-" (base_url_of "anthropic"))
    "https://api.anthropic.com/v1";
  check_eq "gemini base url" (Option.value ~default:"-" (base_url_of "google"))
    "https://generativelanguage.googleapis.com/v1beta/openai";
  check_eq "xai base url" (Option.value ~default:"-" (base_url_of "xai")) "https://api.x.ai/v1";
  check_eq "groq base url" (Option.value ~default:"-" (base_url_of "groq")) "https://api.groq.com/openai/v1";
  check_eq "lmstudio base url" (Option.value ~default:"-" (base_url_of "lmstudio"))
    "http://127.0.0.1:1234/v1";

  (* Registration: every entry must end up usable through the registry. *)
  Coding_extensions.install_catalog_providers ();
  let unregistered =
    List.filter (fun (p : Ai_catalog_spec.provider) -> Ai_registry.get_provider p.id = None) providers
  in
  check_msg "every provider registers" (unregistered = [])
    (String.concat ", " (List.map (fun (p : Ai_catalog_spec.provider) -> p.id) unregistered));

  let wrong_api =
    List.filter
      (fun (p : Ai_catalog_spec.provider) ->
        match Ai_registry.get_provider p.id with
        | Some rp -> not (List.mem_assoc "openai-completions" rp.Ai_registry.streams)
        | None -> true)
      providers
  in
  check "every provider is wired to the OpenAI completions stream" (wrong_api = []);

  (match providers with
  | p :: _ -> (
      let m = List.hd p.models in
      match Ai_registry.get_model (p.id ^ ":" ^ m.id) with
      | exception _ -> check "a catalog model resolves through the registry" false
      | got ->
          check_eq "the resolved model carries its provider's base url" got.Ai_types.base_url p.base_url;
          check_eq "the resolved model keeps its context window"
            (string_of_int got.Ai_types.context_window)
            (string_of_int m.context_window))
  | [] -> check "the catalog is non-empty" false);

  (* Key lookup: "$A,$B" takes the first variable that is actually set, and an
     empty value counts as unset -- the case that exists because Gemini can be
     configured under any of three names. *)
  (match Ai_registry.get_provider "google" with
  | None -> check "the google provider was registered" false
  | Some _ ->
      Unix.putenv "GOOGLE_API_KEY" "";
      Unix.putenv "GOOGLE_GENERATIVE_AI_API_KEY" "from-the-second-name";
      check_eq "a later env var is used when an earlier one is empty"
        (Option.value ~default:"-" (Ai_registry.resolve_api_key "google"))
        "from-the-second-name";
      Unix.putenv "GOOGLE_API_KEY" "from-the-first-name";
      check_eq "the first env var wins when it is set"
        (Option.value ~default:"-" (Ai_registry.resolve_api_key "google"))
        "from-the-first-name";
      Unix.putenv "GOOGLE_API_KEY" "";
      Unix.putenv "GOOGLE_GENERATIVE_AI_API_KEY" "")

(* ------------------------------------------------------------------ *)
(* 2. Text utilities                                                   *)
(* ------------------------------------------------------------------ *)

let test_truncation () =
  section "Truncation";
  let r = Coding_tool_utils.truncate "hello" Coding_tool_utils.Head in
  check "short input is not truncated" (not r.truncated && r.output = "hello");

  let long = String.make 100 'a' in
  let r = Coding_tool_utils.truncate ~max_bytes:10 long Coding_tool_utils.Head in
  check "head keeps the prefix" (r.truncated && r.output = String.make 10 'a' && r.total_bytes = 100);

  let r = Coding_tool_utils.truncate ~max_bytes:10 long Coding_tool_utils.Tail in
  check "tail keeps the suffix" (r.truncated && r.output = String.make 10 'a');

  (* A multi-byte character straddling the cut must not be split. *)
  let emoji = "\xc3\xa9\xc3\xa9\xc3\xa9" in
  (* three 2-byte characters *)
  let r = Coding_tool_utils.truncate ~max_bytes:3 emoji Coding_tool_utils.Head in
  check "head snaps to a character boundary" (r.output = "\xc3\xa9");
  let r = Coding_tool_utils.truncate ~max_bytes:4 emoji Coding_tool_utils.Tail in
  check "tail snaps to a character boundary" (String.length r.output = 4);

  check_eq "format_size bytes" (Coding_tool_utils.format_size 512) "512B";
  check_eq "format_size KB" (Coding_tool_utils.format_size 2048) "2.0KB";

  check_eq "split_lines trailing newline" (String.concat "|" (Coding_tool_utils.split_lines "a\nb\n")) "a|b";
  check_eq "split_lines blank line" (String.concat "|" (Coding_tool_utils.split_lines "a\n\nb")) "a||b";
  check_eq "split_lines crlf" (String.concat "|" (Coding_tool_utils.split_lines "a\r\nb")) "a|b";
  check_eq "split_lines empty" (String.concat "|" (Coding_tool_utils.split_lines "")) "";

  check_eq "count_occurrences" (string_of_int (Coding_tool_utils.count_occurrences "aaa" "aa")) "1";
  check_eq "replace_first" (Coding_tool_utils.replace_first "aXbX" "X" "-") "a-bX"

(* ------------------------------------------------------------------ *)
(* 3. Token estimation and compaction planning                          *)
(* ------------------------------------------------------------------ *)

let test_compaction_math () =
  section "Compaction maths";
  check_eq "text tokens" (string_of_int (Coding_compaction.estimate_text_tokens "abcdefgh")) "2";
  check_eq "empty text tokens" (string_of_int (Coding_compaction.estimate_text_tokens "")) "0";

  let msg s = Coding_messages.Msg (Ai_types.User { content = s }) in

  (* usage is preferred over estimation when it is present *)
  let with_usage =
    Coding_messages.Msg
      (Ai_types.Assistant
         {
           Ai_types.empty_assistant with
           stop_reason = Some Ai_types.Stop;
           usage = Some { Ai_types.input_tokens = 0; output_tokens = 0; cache_read = 0; total_tokens = 1000 };
         })
  in
  (* Four 40-character user messages after it: 4 x ceil(40/4) = 40 estimated tokens. *)
  let estimated = List.init 4 (fun _ -> msg (String.make 40 'x')) in
  check_eq "usage beats estimation"
    (string_of_int (Coding_compaction.estimate_context_tokens (with_usage :: estimated)))
    "1040";

  check "threshold fires below the reserve"
    (Coding_compaction.check_compaction_threshold ~context_tokens:9000 ~context_window:10_000
       { Coding_compaction.default_settings with reserve_tokens = 2000 });
  check "threshold stays quiet above it"
    (not
       (Coding_compaction.check_compaction_threshold ~context_tokens:7000 ~context_window:10_000
          { Coding_compaction.default_settings with reserve_tokens = 2000 }));

  (* Build a tree: header, then alternating user/assistant, then find a cut. *)
  let csm = Coding_session_manager.new_session ~cwd:"/tmp" () in
  for _ = 1 to 10 do
    ignore (Coding_session_manager.append_message csm (msg (String.make 400 'u')));
    ignore
      (Coding_session_manager.append_message csm
         (Coding_messages.Msg
            (Ai_types.Assistant
               { Ai_types.empty_assistant with content = String.make 400 'a'; stop_reason = Some Ai_types.Stop })))
  done;

  let context = Coding_session_manager.build_session_context csm in
  check_eq "context message count" (string_of_int (List.length context.messages)) "20";

  let prep =
    Coding_compaction.prepare_compaction context.messages_entries
      { Coding_compaction.default_settings with keep_recent_tokens = 1000 }
  in
  (match prep with
  | None -> check "cut point found" false
  | Some p ->
      check "cut point found" true;
      check "cut point keeps a non-empty tail" (List.length p.messages_to_summarize > 0);
      check "cut point summarises less than everything"
        (List.length p.messages_to_summarize < List.length context.messages_entries);
      check "previous_summary is empty on the first compaction" (p.previous_summary = None);

      let serialized = Coding_compaction.serialize_messages_for_compaction p.messages_to_summarize in
      check "serialization tags roles"
        (Coding_tool_utils.count_occurrences serialized "role='user'" > 0
        && Coding_tool_utils.count_occurrences serialized "role='assistant'" > 0));

  (* File operation roll-up feeds the summary so the model keeps its bearings. *)
  let ops =
    Coding_compaction.format_file_operations
      [
        Coding_messages.Msg
          (Ai_types.Assistant
             {
               Ai_types.empty_assistant with
               tool_calls =
                 [
                   { Ai_types.id = "1"; name = "read"; arguments = `Assoc [ ("path", `String "a.ml") ] };
                   { Ai_types.id = "2"; name = "write"; arguments = `Assoc [ ("path", `String "b.ml") ] };
                   { Ai_types.id = "3"; name = "read"; arguments = `Assoc [ ("path", `String "b.ml") ] };
                 ];
             });
      ]
  in
  check "read-only and modified files are separated"
    (Coding_tool_utils.count_occurrences ops "<read-files>" = 1
    && Coding_tool_utils.count_occurrences ops "<modified-files>" = 1
    && Coding_tool_utils.count_occurrences ops "a.ml" = 1
    (* Upstream computes read-only as [read - modified], so a file that was both
       read and written is reported only under <modified-files>. *)
    && Coding_tool_utils.count_occurrences ops "b.ml" = 1)

(* ------------------------------------------------------------------ *)
(* 4. Session persistence and rewind                                    *)
(* ------------------------------------------------------------------ *)

let test_session_tree () =
  section "Session tree";
  let home = temp_dir "minipi_home" in
  Unix.putenv "HOME" home;
  Unix.putenv "USERPROFILE" home;
  let cwd = temp_dir "minipi_ws" in

  let csm = Coding_session_manager.new_session ~cwd () in
  check_eq "header is the only entry at first" (string_of_int (List.length csm.Coding_session_manager.entries)) "1";
  check "leaf is unset before any message" (csm.Coding_session_manager.leaf_id = None);

  let u1 = Coding_session_manager.append_message csm (Coding_messages.Msg (Ai_types.User { content = "first" })) in
  ignore u1;
  (* No assistant message yet, so nothing may reach disk. *)
  check "no file before the first assistant message" (not (Sys.file_exists csm.Coding_session_manager.session_file_path));

  ignore
    (Coding_session_manager.append_message csm
       (Coding_messages.Msg
          (Ai_types.Assistant { Ai_types.empty_assistant with content = "reply"; stop_reason = Some Ai_types.Stop })));
  check "file appears after the first assistant message" (Sys.file_exists csm.Coding_session_manager.session_file_path);

  let u2 = Coding_session_manager.append_message csm (Coding_messages.Msg (Ai_types.User { content = "second" })) in
  ignore u2;
  ignore
    (Coding_session_manager.append_message csm
       (Coding_messages.Msg
          (Ai_types.Assistant { Ai_types.empty_assistant with content = "reply2"; stop_reason = Some Ai_types.Stop })));

  let context = Coding_session_manager.build_session_context csm in
  check_eq "context has four messages" (string_of_int (List.length context.messages)) "4";

  (* Reload from disk and check the transcript survived. *)
  let reloaded = Coding_session_manager.read_session_file csm.Coding_session_manager.session_file_path in
  check_eq "reload keeps the session id" reloaded.Coding_session_manager.session_id csm.Coding_session_manager.session_id;
  check_eq "reload keeps the messages"
    (string_of_int (List.length (Coding_session_manager.build_session_context reloaded).messages))
    "4";

  let targets = Coding_session_manager.rewind_entries csm in
  check_eq "two rewind targets (user messages only)" (string_of_int (List.length targets)) "2";

  (* Rewind to the user message that started turn 2: its parent is the previous
     assistant message, so only the first exchange survives. *)
  let t2 = List.nth targets 1 in
  Coding_session_manager.branch csm (Option.value ~default:"" (Coding_entries.parent_id t2));
  let after = Coding_session_manager.build_session_context csm in
  check_eq "rewind truncates the branch" (string_of_int (List.length after.messages)) "2";

  (* The session list should report the file we just wrote. *)
  let rows = Coding_session_manager.list_sessions ~session_dir:(Filename.dirname csm.Coding_session_manager.session_file_path) () in
  check_eq "session is listed" (string_of_int (List.length rows)) "1";
  let first_row = List.hd rows in
  check_eq "title comes from the first user message"
    (match first_row.Coding_session_manager.title with Some t -> t | None -> "")
    "first";

  rm_rf home;
  rm_rf cwd

(* ------------------------------------------------------------------ *)
(* 5. The agent loop, driven by a scripted provider                     *)
(* ------------------------------------------------------------------ *)

let test_agent_loop () =
  section "Agent loop";
  let home = temp_dir "minipi_home2" in
  Unix.putenv "HOME" home;
  Unix.putenv "USERPROFILE" home;
  let cwd = temp_dir "minipi_ws2" in

  let model =
    {
      Ai_types.id = "stub";
      name = "Stub";
      api = "stub";
      provider = "stub";
      base_url = "http://localhost:1";
      reasoning = false;
      thinking_level_map = [];
      context_window = 128_000;
      max_tokens = 1024;
      compat = None;
    }
  in

  let call_count = ref 0 in

  (* Turn 1 streams some text and asks for the write tool. Turn 2 answers. *)
  let stream_fn (_model : Ai_types.ai_model) _context _options (emit : Ai_types.stream_event -> unit Lwt.t) : unit Lwt.t =
    incr call_count;
    let n = !call_count in
    Lwt_list.iter_s emit
      (if n = 1 then
         [
           Ai_types.Text_delta "let me write ";
           Ai_types.Thinking_delta "deciding";
           Ai_types.Text_delta "that file";
           Ai_types.Done
             {
               Ai_types.empty_assistant with
               content = "let me write that file";
               thinking = "deciding";
               stop_reason = Some Ai_types.Tool_use;
               tool_calls =
                 [
                   {
                     Ai_types.id = "call_1";
                     name = "write";
                     arguments = `Assoc [ ("path", `String "out.txt"); ("content", `String "written by the agent") ];
                   };
                 ];
             };
         ]
       else
         [
           Ai_types.Text_delta "done";
           Ai_types.Done
             {
               Ai_types.empty_assistant with
               content = "done";
               stop_reason = Some Ai_types.Stop;
             };
         ])
  in

  let events = ref [] in
  let messages : Coding_messages.session_message list ref = ref [] in

  let tools = Coding_tools.create_all ~cwd in

  Lwt_main.run
    (Agent_loop.run ~stream_fn ~model ~system:"sys" ~messages
       ~prompts:[ Coding_messages.Msg (Ai_types.User { content = "write a file" }) ]
       ~tools ~of_llm:Coding_messages.of_llm ~to_llm:Coding_messages.to_llm_list ~signal:None
       ~get_steering_messages:(fun () -> [])
       ~get_followup_messages:(fun () -> [])
       ~emit:(fun ev ->
         events := Agent_events.type_name ev :: !events;
         Lwt.return_unit));

  let events = List.rev !events in

  check_eq "provider was called twice" (string_of_int !call_count) "2";
  check_eq "two turns" (string_of_int (List.length (List.filter (fun e -> e = "turn_start") events))) "2";

  (* Ordering within the first turn: assistant streams before the tool runs. *)
  let idx name = 
    let rec go i = function
      | [] -> -1
      | x :: tl -> if x = name then i else go (i + 1) tl
    in
    go 0 events
  in
  check "agent_start comes first" (idx "agent_start" = 0);
  check "user message is announced before the first turn" (idx "message_start" > idx "agent_start");
  check "assistant message precedes the tool call" (idx "message_end" < idx "tool_execution_start");
  check "tool call precedes its result" (idx "tool_execution_start" < idx "tool_execution_end");
  check "tool result is announced" (idx "tool_execution_end" < List.length events - 1);
  check "agent_end is last" (idx "agent_end" = List.length events - 1);

  (* The tool really ran, inside the workspace. *)
  let out = Filename.concat cwd "out.txt" in
  check "the write tool created the file" (Sys.file_exists out);
  check_eq "the file has the requested content" (if Sys.file_exists out then read_file out else "") "written by the agent";

  (* History: user, assistant(tool call), tool result, assistant(final) *)
  check_eq "four messages in the session history" (string_of_int (List.length !messages)) "4";
  (match List.nth !messages 1 with
  | Coding_messages.Msg (Ai_types.Assistant a) ->
      check_eq "assistant recorded the tool call" (string_of_int (List.length a.tool_calls)) "1";
      check_eq "streamed thinking is kept" a.thinking "deciding"
  | _ -> check "second message is the assistant" false);
  (match List.nth !messages 2 with
  | Coding_messages.Msg (Ai_types.Tool_result r) ->
      check "tool result is successful" (not r.is_error);
      check_eq "tool result carries the call id" r.tool_call_id "call_1"
  | _ -> check "third message is the tool result" false);

  (* The tool must refuse to escape the workspace. *)
  let escaped =
    try
      ignore (Coding_tool_utils.resolve_path ~cwd "../outside.txt");
      false
    with _ -> true
  in
  check "path escape is refused" escaped;

  rm_rf home;
  rm_rf cwd

(* ------------------------------------------------------------------ *)
(* 6. Extension hooks                                                   *)
(* ------------------------------------------------------------------ *)

let test_extensions () =
  section "Extensions";
  let cwd = temp_dir "minipi_ws3" in
  let rt = Coding_extensions.create_runtime ~cwd in
  Coding_extensions.install_bundled rt;

  let commands = Coding_extensions.get_all_commands rt in
  check "permission command is registered"
    (List.exists (fun (c : Coding_extensions.command) -> c.name = "permission") commands);

  check "the fireworks provider is registered" (Ai_registry.get_provider "fireworks" <> None);
  (match Ai_registry.get_model "fireworks:accounts/fireworks/models/minimax-m3" with
  | exception _ -> check "model resolves through the registry" false
  | m -> check_eq "model resolves through the registry" m.Ai_types.provider "fireworks");

  (* A descriptor is the OCaml counterpart of a Python extension module. *)
  let dir = Filename.concat cwd "ext" in
  Coding_tool_utils.mkdir_p dir;
  let oc = open_out (Filename.concat dir "guard.json") in
  output_string oc
    {|{"name":"guard",
       "commands":[{"name":"hello","description":"say hi","notify":"hi there"}],
       "hooks":{"tool_call":[{"tool":"bash","block":true,"reason":"no bash here"}]}}|};
  close_out oc;

  Coding_extensions.load_extensions_from_dir rt dir;
  check "descriptor command is registered"
    (List.exists (fun (c : Coding_extensions.command) -> c.name = "hello") (Coding_extensions.get_all_commands rt));

  (* Checking the hook needs a runtime holding *only* the descriptor. The
     bundled permission_gate registers its own bash guard, and it always blocks
     bash in this test because there is no UI channel to ask through — so with
     the full runtime we could not tell which extension did the blocking. *)
  let descriptor_only = Coding_extensions.create_runtime ~cwd in
  Coding_extensions.load_extensions_from_dir descriptor_only dir;

  let wrapped =
    List.map (Coding_extensions.wrap_tool descriptor_only) (Coding_tools.create_all ~cwd)
  in
  let bash = List.find (fun (t : Agent_tools.t) -> t.name = "bash") wrapped in
  let result = Lwt_main.run (bash.execute (`Assoc [ ("command", `String "echo hi") ]) None) in
  check_eq "the descriptor hook blocked the bash tool" result
    "Tool call blocked by extension: no bash here";

  (* The other half of the story: the bundled gate blocks bash on its own. *)
  let bundled_bash =
    List.find
      (fun (t : Agent_tools.t) -> t.name = "bash")
      (List.map (Coding_extensions.wrap_tool rt) (Coding_tools.create_all ~cwd))
  in
  let bundled_result =
    Lwt_main.run (bundled_bash.execute (`Assoc [ ("command", `String "echo hi") ]) None)
  in
  check "the bundled permission gate blocks bash without a UI channel"
    (Coding_tool_utils.count_occurrences bundled_result "blocked" > 0);

  let read_tool = List.find (fun (t : Agent_tools.t) -> t.name = "read") wrapped in
  let name = Filename.concat cwd "in.txt" in
  Coding_tool_utils.write_file_text name "hello world\n";
  let out = Lwt_main.run (read_tool.execute (`Assoc [ ("path", `String "in.txt") ]) None) in
  check_eq "unrelated tools still work" out "1. hello world";
  ignore name;

  rm_rf cwd

(* ------------------------------------------------------------------ *)

let () =
  Random.self_init ();
  Printf.printf "mini-pi OCaml port: verification suite\n";

  (* Nothing in this suite may touch the developer's real ~/.mini-pi, so the
     home directory is redirected before any session or auth code runs. *)
  let home = temp_dir "minipi_suite_home" in
  Unix.putenv "HOME" home;
  Unix.putenv "USERPROFILE" home;

  test_json_encoding ();
  test_openai_stream_parser ();
  test_http_head_parsing ();
  test_catalog ();
  test_truncation ();
  test_compaction_math ();
  test_session_tree ();
  test_agent_loop ();
  test_extensions ();

  rm_rf home;
  Printf.printf "\n%s (%d failure%s)\n"
    (if !failures = 0 then "ALL CHECKS PASSED" else "FAILURES PRESENT")
    !failures
    (if !failures = 1 then "" else "s");
  exit (if !failures = 0 then 0 else 1)
