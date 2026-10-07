(* Port of coding/events.py plus the JSON encoding of the whole session event
   vocabulary. The encoding has to match pydantic's [model_dump(mode="json")]
   exactly, because the original TypeScript TUI consumes these objects verbatim
   over the RPC channel. *)

type compaction_reason = Manual | Threshold | Overflow

let compaction_reason_to_string = function
  | Manual -> "manual"
  | Threshold -> "threshold"
  | Overflow -> "overflow"

type t =
  | Agent of Coding_messages.session_message Agent_events.t
  | Compaction_start of compaction_reason
  | Compaction_end of { result : string option; error_message : string option }

let msg_json = Coding_messages.to_json

let to_json (ev : t) : Yojson.Safe.t =
  match ev with
  | Agent Agent_events.Agent_start -> `Assoc [ ("type", `String "agent_start") ]
  | Agent (Agent_events.Agent_end ms) ->
      `Assoc [ ("type", `String "agent_end"); ("messages", `List (List.map msg_json ms)) ]
  | Agent Agent_events.Turn_start -> `Assoc [ ("type", `String "turn_start") ]
  | Agent (Agent_events.Turn_end (a, results)) ->
      `Assoc
        [
          ("type", `String "turn_end");
          ("message", Ai_types.assistant_to_json a);
          ("tool_results", `List (List.map msg_json results));
        ]
  | Agent (Agent_events.Message_start m) ->
      `Assoc [ ("type", `String "message_start"); ("message", msg_json m) ]
  | Agent (Agent_events.Message_end m) ->
      `Assoc [ ("type", `String "message_end"); ("message", msg_json m) ]
  | Agent (Agent_events.Message_update (Agent_events.Text_delta d)) ->
      `Assoc
        [
          ("type", `String "message_update");
          ( "assistant_message_event",
            `Assoc [ ("type", `String "text_delta"); ("delta", `String d) ] );
        ]
  | Agent (Agent_events.Message_update (Agent_events.Thinking_delta d)) ->
      `Assoc
        [
          ("type", `String "message_update");
          ( "assistant_message_event",
            `Assoc [ ("type", `String "thinking_delta"); ("delta", `String d) ] );
        ]
  | Agent (Agent_events.Tool_execution_start { tool_call_id; tool_name; arguments }) ->
      `Assoc
        [
          ("type", `String "tool_execution_start");
          ("tool_call_id", `String tool_call_id);
          ("tool_name", `String tool_name);
          ("arguments", arguments);
        ]
  | Agent (Agent_events.Tool_execution_end { tool_call_id; tool_name; result; is_error }) ->
      `Assoc
        [
          ("type", `String "tool_execution_end");
          ("tool_call_id", `String tool_call_id);
          ("tool_name", `String tool_name);
          ("result", `String result);
          ("is_error", `Bool is_error);
        ]
  | Compaction_start reason ->
      `Assoc
        [ ("type", `String "compaction_start"); ("reason", `String (compaction_reason_to_string reason)) ]
  | Compaction_end { result; error_message } ->
      `Assoc
        [
          ("type", `String "compaction_end");
          ("result", match result with Some r -> `String r | None -> `Null);
          ("error_message", match error_message with Some e -> `String e | None -> `Null);
        ]
