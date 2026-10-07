(* Port of agent/loop.py

   This is the heart of the agent: alternate between asking the model for a
   completion and executing whichever tools it asked for, until it answers
   without requesting a tool.

   The Python original is an async generator. We use a push-based [emit]
   callback instead: the same computation, expressed in a style that needs no
   generator machinery on the OCaml side. *)

open Lwt.Syntax

(* Deliberately large so the agent can run for a long time, but bounded so a
   runaway loop still terminates. *)
let max_turns = 1000

let run (type a) ~(stream_fn : Ai_types.stream_fn) ~(model : Ai_types.ai_model)
    ~(system : string) ~(messages : a list ref) ~(prompts : a list)
    ~(tools : Agent_tools.t list) ~(of_llm : Ai_types.message -> a)
    ~(to_llm : a list -> Ai_types.message list) ~(signal : Ai_cancellation.t option)
    ~(get_steering_messages : unit -> string list)
    ~(get_followup_messages : unit -> string list)
    ~(emit : a Agent_events.t -> unit Lwt.t) : unit Lwt.t =
  (* Everything appended from agent_start to agent_end, which is what
     Agent_end reports. *)
  let appended : a list ref = ref [] in

  let append (m : a) =
    messages := !messages @ [ m ];
    appended := m :: !appended

  in
  let new_messages () = List.rev !appended in
  let cancelled () = match signal with Some s -> Ai_cancellation.is_cancelled s | None -> false in

  let announce (m : a) =
    let* () = emit (Agent_events.Message_start m) in
    emit (Agent_events.Message_end m)
  in

  let user_msg text : a = of_llm (Ai_types.User { content = text }) in
  let assistant_msg (m : Ai_types.assistant_message) : a = of_llm (Ai_types.Assistant m) in

  List.iter append prompts;
  let* () = emit Agent_events.Agent_start in
  let* () = Lwt_list.iter_s announce prompts in

  let pending_queued : string list ref = ref [] in
  (* Set by the two early-exit paths below. Upstream *returns* from the
     generator right after announcing agent_end there, so the outer loop must
     not go on to look for follow-up messages. *)
  let terminated = ref false in

  let rec outer () : unit Lwt.t =
    let is_assistant_done = ref false in
    let turn = ref 0 in

    let rec inner () : unit Lwt.t =
      if (not !is_assistant_done) || List.length !pending_queued > 0 then (
        incr turn;
        let* () = emit Agent_events.Turn_start in

        if !turn > max_turns || cancelled () then (
          let error_message =
            if !turn < max_turns then "Operation cancelled" else "Max turn reached"
          in
          let aborted = Ai_types.assistant ~stop_reason:Ai_types.Aborted ~error_message () in
          append (assistant_msg aborted);
          let* () = announce (assistant_msg aborted) in
          let* () = emit (Agent_events.Turn_end (aborted, [])) in
          let* () = emit (Agent_events.Agent_end (new_messages ())) in
          terminated := true;
          Lwt.return_unit)
        else (
          (* Drain any steering messages queued while we were working. *)
          let queued = !pending_queued in
          pending_queued := [];
          let* () =
            Lwt_list.iter_s
              (fun msg ->
                let m = user_msg msg in
                append m;
                announce m)
              queued
          in

          let* () = emit (Agent_events.Message_start (assistant_msg Ai_types.empty_assistant)) in

          let assistant_message : Ai_types.assistant_message option ref = ref None in
          let* () =
            stream_fn model
              {
                Ai_types.system = system;
                messages = to_llm !messages;
                tools = List.map Agent_tools.to_ai_tool tools;
              }
              { Ai_types.default_stream_options with signal }
              (fun ev ->
                match ev with
                | Ai_types.Text_delta d ->
                    emit (Agent_events.Message_update (Agent_events.Text_delta d))
                | Ai_types.Thinking_delta d ->
                    emit (Agent_events.Message_update (Agent_events.Thinking_delta d))
                | Ai_types.Done m ->
                    assistant_message := Some m;
                    Lwt.return_unit)
          in

          (* A cancellation observed mid-stream overrides whatever the provider
             reported, matching the check inside the Python async-for body. *)
          if cancelled () then
            assistant_message :=
              Some
                (Ai_types.assistant ~stop_reason:Ai_types.Aborted
                   ~error_message:"Operation cancelled" ());

          let assistant_message =
            match !assistant_message with
            | Some m -> m
            | None ->
                Ai_types.assistant ~stop_reason:Ai_types.Error
                  ~error_message:"No assistant message received" ()
          in

          let am = assistant_msg assistant_message in
          append am;
          let* () = emit (Agent_events.Message_end am) in

          match assistant_message.stop_reason with
          | Some (Ai_types.Error | Ai_types.Aborted) ->
              let* () = emit (Agent_events.Turn_end (assistant_message, [])) in
              let* () = emit (Agent_events.Agent_end (new_messages ())) in
              terminated := true;
              Lwt.return_unit
          | _ ->
              is_assistant_done := List.length assistant_message.tool_calls = 0;
              let is_truncated = assistant_message.stop_reason = Some Ai_types.Length in
              let tool_results : a list ref = ref [] in

              let* () =
                Lwt_list.iter_s
                  (fun (tool_call : Ai_types.tool_call) ->
                    let* () =
                      emit
                        (Agent_events.Tool_execution_start
                           {
                             tool_call_id = tool_call.id;
                             tool_name = tool_call.name;
                             arguments = tool_call.arguments;
                           })
                    in

                    let* content, is_error =
                      if cancelled () then Lwt.return ("Operation cancelled", true)
                      else if is_truncated then
                        Lwt.return
                          ( Printf.sprintf
                              "Tool call '%s' was not executed: the response hit the output token limit, so \
                               its arguments may be truncated. Re-issue the tool call with complete \
                               arguments."
                              tool_call.name,
                            true )
                      else
                        match Agent_tools.find tools tool_call.name with
                        | None ->
                            Lwt.return
                              (Printf.sprintf "Error: tool '%s' not found" tool_call.name, true)
                        | Some tool -> (
                            (* Validate before executing so a malformed tool call
                               comes back as an errored tool result instead of
                               killing the whole run. *)
                            match
                              Ai_validation.validate_tool_arguments tool.parameters
                                tool_call.arguments
                            with
                            | exception exn ->
                                Lwt.return
                                  ( Printf.sprintf "Error executing tool '%s': %s" tool_call.name
                                      (match exn with
                                      | Ai_validation.Validation_error m -> m
                                      | e -> Printexc.to_string e),
                                    true )
                            | () ->
                                Lwt.catch
                                  (fun () ->
                                    let* r = tool.execute tool_call.arguments signal in
                                    Lwt.return (r, false))
                                  (fun e ->
                                    Lwt.return
                                      ( Printf.sprintf "Error executing tool '%s': %s"
                                          tool_call.name (Printexc.to_string e),
                                        true )))
                    in

                    let m =
                      of_llm
                        (Ai_types.Tool_result
                           {
                             tool_call_id = tool_call.id;
                             tool_name = tool_call.name;
                             content;
                             is_error;
                           })
                    in
                    append m;
                    tool_results := !tool_results @ [ m ];

                    let* () =
                      emit
                        (Agent_events.Tool_execution_end
                           {
                             tool_call_id = tool_call.id;
                             tool_name = tool_call.name;
                             result = content;
                             is_error;
                           })
                    in
                    announce m)
                  assistant_message.tool_calls
              in

              let* () = emit (Agent_events.Turn_end (assistant_message, !tool_results)) in
              pending_queued := get_steering_messages ();
              inner ()))
      else Lwt.return_unit
    in

    let* () = inner () in
    if !terminated then Lwt.return_unit
    else (
      pending_queued := get_followup_messages ();
      if List.length !pending_queued = 0 then
        (* Normal completion: upstream yields agent_end once the outer loop
           breaks, with everything appended since agent_start. *)
        emit (Agent_events.Agent_end (new_messages ()))
      else outer ())
  in

  outer ()
