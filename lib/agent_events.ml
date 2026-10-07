(* Port of agent/events.py

   The Python original defines the event vocabulary over a generic
   [AgentMessage[CustomMessage]]. We keep the same genericity with a type
   parameter, so the coding layer can carry its summary pseudo-message.

   Event ordering for the prompt "read foo.py and explain it":

     Agent_start
       Message_start/Message_end   (the user message)
       Turn_start
         Message_start               (assistant)
         Message_update*             (streamed deltas)
         Message_end
         Tool_execution_start / Tool_execution_end
         Message_start/Message_end   (tool result)
       Turn_end
       Turn_start ... etc until the assistant stops without tool calls
     Agent_end

   Only assistant messages stream; every other message is complete when it is
   announced, hence the immediate start/end pair. *)

type delta = Text_delta of string | Thinking_delta of string

type 'a t =
  | Agent_start
  | Agent_end of 'a list
  | Turn_start
  | Turn_end of Ai_types.assistant_message * 'a list  (* assistant, tool_results *)
  | Message_start of 'a
  | Message_update of delta
  | Message_end of 'a
  | Tool_execution_start of {
      tool_call_id : string;
      tool_name : string;
      arguments : Yojson.Safe.t;
    }
  | Tool_execution_end of {
      tool_call_id : string;
      tool_name : string;
      result : string;
      is_error : bool;
    }

let type_name = function
  | Agent_start -> "agent_start"
  | Agent_end _ -> "agent_end"
  | Turn_start -> "turn_start"
  | Turn_end _ -> "turn_end"
  | Message_start _ -> "message_start"
  | Message_update _ -> "message_update"
  | Message_end _ -> "message_end"
  | Tool_execution_start _ -> "tool_execution_start"
  | Tool_execution_end _ -> "tool_execution_end"
