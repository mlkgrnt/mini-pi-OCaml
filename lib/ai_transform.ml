(* Port of ai/transform.py

   Providers reject a transcript in which an assistant message declares tool
   calls that have no matching tool result. Rewinding and compaction can both
   produce such a transcript, so we repair it by inserting synthetic errored
   tool results before the next user / assistant boundary. *)

let transform_messages (messages : Ai_types.message list) : Ai_types.message list =
  let out = ref [] in
  let pending_tool_calls = ref [] in
  let existing_tool_result_ids = ref [] in

  let insert_synthetic_tool_results () =
    List.iter
      (fun (tc : Ai_types.tool_call) ->
        if not (List.mem tc.id !existing_tool_result_ids) then
          out :=
            Ai_types.Tool_result
              {
                tool_call_id = tc.id;
                tool_name = tc.name;
                content = "No result provided";
                is_error = true;
              }
            :: !out)
      !pending_tool_calls;
    pending_tool_calls := [];
    existing_tool_result_ids := []
  in

  List.iter
    (fun (msg : Ai_types.message) ->
      match msg with
      | Ai_types.Assistant a ->
          insert_synthetic_tool_results ();
          if a.stop_reason = Some Ai_types.Error || a.stop_reason = Some Ai_types.Aborted then ()
          else (
            if List.length a.tool_calls > 0 then pending_tool_calls := a.tool_calls;
            out := msg :: !out)
      | Ai_types.Tool_result r ->
          existing_tool_result_ids := r.tool_call_id :: !existing_tool_result_ids;
          out := msg :: !out
      | Ai_types.User _ ->
          insert_synthetic_tool_results ();
          out := msg :: !out)
    messages;

  insert_synthetic_tool_results ();
  List.rev !out
