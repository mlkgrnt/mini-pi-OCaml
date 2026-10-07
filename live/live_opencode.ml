(* Live end-to-end check: the OCaml port against a real provider.
 *
 *   OPENCODE_API_KEY=sk-... dune exec live/live_opencode.exe
 *   OPENCODE_MODEL=glm-5.3   ...        (default: deepseek-v4.1-flash)
 *
 * Everything else in the suite is offline by design -- the RPC smoke test
 * deliberately runs with a missing key, because that is the path that proves
 * the event pipeline without touching the network. This program is the other
 * half of the story: it puts a real model behind the very same agent loop, so
 * the parts that cannot be faked are actually exercised --
 *
 *   - HTTPS through the curl transport in ai_http.ml
 *   - real SSE framing and delta parsing in ai_openai.ml
 *   - reasoning_content handling, when the model chooses to emit any
 *     (it is reported, not asserted -- see the note in the "Model output"
 *     section -- and the parser path is covered offline)
 *   - a genuine tool-call round trip: model asks, the loop runs the tool,
 *     the result goes back, the model answers
 *   - usage accounting read out of the stream
 *
 * It is an executable, not a (test) stanza, so `dune runtest` never picks it up.
 *
 * The provider is registered here rather than compiled into the library on
 * purpose. The framework is generic OpenAI Chat Completions, but OpenCode's
 * /models endpoint publishes only id/object/created/owned_by -- no context
 * window, no max-output metadata. Baking invented numbers into the shipped port
 * would silently skew compaction and overflow decisions, so the limits below
 * are an explicit assumption of *this harness*, not a claim about the provider.
 * They only affect when the port would decide to compact, which this run is far
 * too short to reach.
 *)

open Mini_pi

let failures = ref 0

let check name cond extra =
  if cond then Printf.printf "  ok    %s\n" name
  else (
    incr failures;
    Printf.printf "  FAIL  %s%s\n" name (if extra = "" then "" else "\n        " ^ extra))

let section s = Printf.printf "\n== %s ==\n" s

let rec rm_rf path =
  if Sys.file_exists path then
    if Sys.is_directory path then (
      Array.iter
        (fun c -> rm_rf (Filename.concat path c))
        (try Sys.readdir path with _ -> [||]);
      try Unix.rmdir path with _ -> ())
    else try Unix.unlink path with _ -> ()

(* ------------------------------------------------------------------ *)
(* Provider registration                                               *)
(* ------------------------------------------------------------------ *)

let provider_name = "opencode"
let base_url = "https://opencode.ai/inference/openai/v1"
let api_name = "openai-completions"

(* Assumptions of this harness; see the header. Deliberately conservative. *)
let assumed_context_window = 128_000
let assumed_max_tokens = 8_192

let make_model id name =
  {
    Ai_types.id;
    name;
    api = api_name;
    provider = provider_name;
    base_url;
    reasoning = true;
    thinking_level_map = [];
    context_window = assumed_context_window;
    max_tokens = assumed_max_tokens;
    compat =
      Some
        {
          Ai_types.supports_usage_in_streaming = true;
          max_tokens_field = Some "max_tokens";
        };
  }

let () =
  if Ai_registry.get_provider provider_name = None then
    Ai_registry.register_inference_provider
      {
        Ai_registry.name = provider_name;
        api_key = Some "$OPENCODE_API_KEY";
        streams = [ (api_name, Ai_openai.stream_openai_completions) ];
        models =
          [
            make_model "deepseek-v4.1-flash" "DeepSeek V4.1 Flash";
            make_model "qwen3.8-flash" "Qwen3.8 Flash";
            make_model "glm-5.3" "GLM 5.3";
            make_model "space-bunny-free" "Space Bunny Free";
          ];
      }

(* ------------------------------------------------------------------ *)

let () =
  Random.self_init ();
  Printf.printf "mini-pi OCaml port: live provider check\n";

  let model_id = match Sys.getenv_opt "OPENCODE_MODEL" with
    | Some m when String.trim m <> "" -> String.trim m
    | _ -> "deepseek-v4.1-flash"
  in
  let model = try Ai_registry.get_model (provider_name ^ ":" ^ model_id) with
    | exn -> Printf.printf "\nFAIL: %s\n" (Printexc.to_string exn); exit 1
  in
  Printf.printf "provider=%s model=%s\n" provider_name model_id;

  (* Keep the run away from the developer's real ~/.mini-pi. *)
  let root = Filename.concat (Filename.get_temp_dir_name ()) "minipi_live" in
  rm_rf root;
  Coding_tool_utils.mkdir_p root;
  let cwd = Filename.concat root "ws" in
  Coding_tool_utils.mkdir_p cwd;
  Unix.putenv "HOME" root;
  Unix.putenv "USERPROFILE" root;

  let messages : Coding_messages.session_message list ref = ref [] in
  let trace = ref [] in
  let t0 = ref (Unix.gettimeofday ()) in
  let saw_thinking = ref false in

  (* Print every event as it arrives, flushed. Without this the whole run is a
     black box until it finishes, which is useless when something stalls. *)
  let emit (ev : Coding_messages.session_message Agent_events.t) =
    let name = Agent_events.type_name ev in
    trace := !trace @ [ name ];
    (match ev with
    | Agent_events.Message_update (Agent_events.Text_delta d) ->
        Printf.printf "  .text %S\n%!" d
    | Agent_events.Message_update (Agent_events.Thinking_delta d) ->
        saw_thinking := true;
        Printf.printf "  .think %S\n%!" d
    | _ -> Printf.printf "  [%s] %6.2fs\n%!" name (Unix.gettimeofday () -. !t0));
    Lwt.return_unit
  in

  let tools = Coding_tools.create_all ~cwd in
  let prompt =
    "Create a file named report.txt in the current directory containing exactly: \
     hello from opencode\n\
     Then reply with the single word DONE."
  in

  section "Agent run";
  (* Agent_loop.run returns unit Lwt.t, so a failure has to be caught out into a
     ref rather than turned into a different return type. *)
  let loop_error = ref None in
  let started = Unix.gettimeofday () in
  t0 := started;
  Lwt_main.run
    (Lwt.catch
       (fun () ->
         Agent_loop.run ~stream_fn:Ai_registry.stream ~model ~system:"You are a terse assistant."
           ~messages
           ~prompts:[ Coding_messages.Msg (Ai_types.User { content = prompt }) ]
           ~tools ~of_llm:Coding_messages.of_llm ~to_llm:Coding_messages.to_llm_list
           ~signal:None
           ~get_steering_messages:(fun () -> [])
           ~get_followup_messages:(fun () -> [])
           ~emit)
       (fun exn ->
         loop_error := Some (Printexc.to_string exn);
         Lwt.return_unit));
  let elapsed = Unix.gettimeofday () -. started in
  Printf.printf "  (%.1fs)\n" elapsed;
  (match !loop_error with
  | Some e -> check "the agent loop completed" false e
  | None -> check "the agent loop completed" true "");

  section "Event trace";
  Printf.printf "  %s\n" (String.concat " -> " !trace);

  (* Note: providers are allowed to be chatty about which events they emit, so
     these assertions are about the *shape* of a real turn, not an exact list. *)
  let has n = List.mem n !trace in
  check "agent_start was emitted" (has "agent_start") "";
  check "at least one turn ran" (has "turn_start") "";
  check "an assistant message arrived" (has "message_end") "";
  check "the run ended with agent_end" (List.nth !trace (List.length !trace - 1) = "agent_end") "";
  check "the model asked for a tool" (has "tool_execution_start") "";
  check "the tool result came back" (has "tool_execution_end") "";
  check "the model got a second turn after the tool ran"
    (List.length (List.filter (fun e -> e = "turn_start") !trace) >= 2) "";

  section "Tool round trip";
  let out = Filename.concat cwd "report.txt" in
  check "the write tool created report.txt on disk" (Sys.file_exists out) "";
  let content = if Sys.file_exists out then Coding_tool_utils.read_file_text out else "" in
  check "the file has the content the prompt asked for"
    (String.trim content = "hello from opencode")
    (Printf.sprintf "got: %S" content);

  section "Model output";
  let assistant =
    List.fold_left
      (fun acc m ->
        match m with
        | Coding_messages.Msg (Ai_types.Assistant a) -> Some a
        | _ -> acc)
      None !messages
  in
  (match assistant with
  | None -> check "an assistant message is in the history" false ""
  | Some a ->
      check "the model produced text" (String.length (String.trim a.content) > 0)
        (Printf.sprintf "content=%S" a.content);
      check "the model reported a stop_reason" (a.stop_reason <> None) "";
      (* Reasoning is reported, not asserted. These models *can* emit
         reasoning_content, but they do not do so on every call -- a terse
         "DONE" turn often has none. Making this a hard gate would test the
         model's mood rather than the port, so it is a soft probe: it
         distinguishes "the provider sent nothing" from "we dropped what it
         sent", and the parser path itself is covered deterministically by the
         offline suite (test_mini_pi.ml, "OpenAI SSE stream parsing"). *)
      if String.length a.thinking > 0 then
        Printf.printf "  ok    streamed reasoning was captured (%d chars)\n%!"
          (String.length a.thinking)
      else if !saw_thinking then
        Printf.printf
          "  note  a thinking delta streamed but did not survive into the final \
           assistant message\n%!"
      else
        Printf.printf "  skip  the provider emitted no reasoning_content on this call\n%!";
      check "usage was read out of the stream" (a.usage <> None)
        (match a.usage with
        | Some u -> Printf.sprintf "total_tokens=%d" u.total_tokens
        | None -> "no usage"));

  (* ------------------------------------------------------------------ *)
  (* The failure path, against the same real endpoint.                   *)
  (* ------------------------------------------------------------------ *)
  (* A rejected key must surface the provider's own error. This is the case
     the proxy-aware head parser fixed: the reply to CONNECT is itself a
     "200", and taking it for the response status meant a 401 was never seen,
     the error body was handed to the SSE parser instead, and the run failed
     with "Stream ended without finish_reason" -- a message that points at the
     wrong layer entirely and hides the actual cause from the user. *)
  section "Error path (deliberately invalid key)";
  let err_events = ref [] in
  Lwt_main.run
    (Lwt.catch
       (fun () ->
         Ai_registry.stream model
           { Ai_types.system = "You are a terse assistant."; messages = [ Ai_types.User { content = "hi" } ]; tools = [] }
           { Ai_types.api_key = Some "sk-deliberately-invalid"; signal = None; max_retries = 0; timeout_seconds = 30.0 }
           (fun ev ->
             err_events := !err_events @ [ ev ];
             Lwt.return_unit))
       (fun _ -> Lwt.return_unit));
  (match List.filter_map (function Ai_types.Done a -> Some a | _ -> None) !err_events with
  | [ a ] ->
      let msg = match a.error_message with Some m -> m | None -> "" in
      check "a rejected key is reported as an error" (a.stop_reason = Some Ai_types.Error) "";
      check "the provider's own error body is surfaced, not swallowed" (String.length (String.trim msg) > 0)
        "the error message is empty";
      check "the failure is not misreported as a missing finish_reason"
        (Coding_tool_utils.count_occurrences msg "finish_reason" = 0)
        (Printf.sprintf "message=%S" msg);
      let shown = String.trim msg in
      Printf.printf "  note  provider said: %s\n%!"
        (if String.length shown > 200 then String.sub shown 0 200 ^ "..." else shown)
  | other ->
      check "exactly one Done event on failure"
        (string_of_int (List.length other) = "1")
        "expected the stream to end with a single Done carrying the error");

  (* ------------------------------------------------------------------ *)

  rm_rf root;
  Printf.printf "\n%s (%d failure%s)\n"
    (if !failures = 0 then "ALL CHECKS PASSED" else "FAILURES PRESENT")
    !failures
    (if !failures = 1 then "" else "s");
  exit (if !failures = 0 then 0 else 1)
