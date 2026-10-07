(* Port of coding/messages.py

   Messages that only exist in the coding layer, i.e. the summary that replaces
   a compacted stretch of conversation. *)

type session_message =
  | Msg of Ai_types.message
  | Compaction_summary of string

let of_llm (m : Ai_types.message) : session_message = Msg m

let to_llm (m : session_message) : Ai_types.message =
  match m with
  | Msg m -> m
  | Compaction_summary s ->
      Ai_types.User
        {
          content =
            "The conversation history before this point was compacted into the following summary:\n<summary>\n"
            ^ s ^ "\n</summary>";
        }

let to_llm_list (ms : session_message list) : Ai_types.message list = List.map to_llm ms

let summary (m : session_message) : string option =
  match m with Compaction_summary s -> Some s | Msg _ -> None

let role (m : session_message) : string =
  match m with
  | Compaction_summary _ -> "compaction_summary"
  | Msg x -> Ai_types.message_role x

let is_user (m : session_message) =
  match m with Msg (Ai_types.User _) -> true | _ -> false

let is_assistant (m : session_message) =
  match m with Msg (Ai_types.Assistant _) -> true | _ -> false

let as_assistant (m : session_message) : Ai_types.assistant_message option =
  match m with Msg (Ai_types.Assistant a) -> Some a | _ -> None

let to_json (m : session_message) : Yojson.Safe.t =
  match m with
  | Msg x -> Ai_types.to_json x
  | Compaction_summary s ->
      `Assoc [ ("role", `String "compaction_summary"); ("summary", `String s) ]

let of_json (j : Yojson.Safe.t) : session_message =
  match Ai_json.str_opt j "role" with
  | Some "compaction_summary" -> Compaction_summary (Ai_json.str j "summary" "")
  | _ -> Msg (Ai_types.of_json j)
