(* Port of coding/compaction/*.py

   When the context approaches the model's window we replace the oldest stretch
   of conversation with a structured summary produced by the model itself. The
   most recent messages survive verbatim, and the cut is snapped to a message
   boundary that is legal to start a prompt with (a user or assistant message;
   never a tool result, which is meaningless without the call it answers). *)

open Lwt.Syntax

(* Heuristic estimation. 4 characters per token is crude but stable, and it is
   only ever used to decide *when* to compact. *)
let chars_per_token = 4

let estimate_text_tokens (text : string) : int =
  if text = "" then 0
  else max 1 ((String.length text + chars_per_token - 1) / chars_per_token)

let estimate_message_tokens (m : Coding_messages.session_message) : int =
  match m with
  | Coding_messages.Msg (Ai_types.User u) -> estimate_text_tokens u.content
  | Coding_messages.Msg (Ai_types.Assistant a) ->
      estimate_text_tokens a.content
      + List.fold_left
          (fun acc (tc : Ai_types.tool_call) ->
            acc + estimate_text_tokens tc.name + estimate_text_tokens (Yojson.Safe.to_string tc.arguments))
          0 a.tool_calls
  | Coding_messages.Msg (Ai_types.Tool_result r) ->
      estimate_text_tokens r.tool_name + estimate_text_tokens r.content
  | Coding_messages.Compaction_summary s -> estimate_text_tokens s

(* Usage is only trustworthy when it carries real numbers. *)
let extract_usage_tokens (a : Ai_types.assistant_message) : int option =
  match (a.stop_reason, a.usage) with
  | Some Ai_types.Error, _ | Some Ai_types.Aborted, _ | _, None -> None
  | _, Some u ->
      if u.total_tokens > 0 then Some u.total_tokens
      else if u.input_tokens > 0 && u.output_tokens > 0 then Some (u.input_tokens + u.output_tokens)
      else None

(* Prefer the provider's own accounting from the newest message that has it,
   and only estimate the messages that came after. *)
let estimate_context_tokens (messages : Coding_messages.session_message list) : int =
  let arr = Array.of_list messages in
  let n = Array.length arr in
  (* One ref, not two: the usage count and the index it came from are always
     written together, and keeping them separate left an unreachable
     (Some _, None) state that the type checker rightly complained about. *)
  let last = ref None in
  (try
     for i = n - 1 downto 0 do
       match arr.(i) with
       | Coding_messages.Msg (Ai_types.Assistant a) -> (
           match extract_usage_tokens a with
           | Some t ->
               last := Some (t, i);
               raise Exit
           | None -> ())
       | _ -> ()
     done
   with Exit -> ());
  match !last with
  | None -> Array.fold_left (fun acc m -> acc + estimate_message_tokens m) 0 arr
  | Some (used, idx) ->
      let trailing = ref 0 in
      for i = idx + 1 to n - 1 do
        trailing := !trailing + estimate_message_tokens arr.(i)
      done;
      used + !trailing

type settings = {
  reserve_tokens : int; (* headroom left for the model's own output *)
  keep_recent_tokens : int; (* budget for messages that survive compaction *)
  enabled : bool;
}

let default_settings = { reserve_tokens = 25_000; keep_recent_tokens = 20_000; enabled = true }

let check_compaction_threshold ~(context_tokens : int) ~(context_window : int)
    (s : settings) : bool =
  context_tokens > context_window - s.reserve_tokens

let is_cut_point_message (m : Coding_messages.session_message) =
  match m with
  | Coding_messages.Msg (Ai_types.User _) | Coding_messages.Msg (Ai_types.Assistant _) -> true
  | _ -> false

(* Walk backwards accumulating tokens; remember the most recent legal cut point
   and return it once the recent-message budget is exhausted. *)
let find_cut_point (entries : Coding_entries.t list) ~(keep_recent_tokens : int) : int option =
  let arr = Array.of_list entries in
  let accumulated = ref 0 and last_cut_point = ref None in
  (try
     for i = Array.length arr - 1 downto 0 do
       match Coding_traversal.entry_to_message arr.(i) with
       | None -> ()
       | Some message ->
           if is_cut_point_message message then last_cut_point := Some i;
           accumulated := !accumulated + estimate_message_tokens message;
           if !accumulated >= keep_recent_tokens && !last_cut_point <> None then raise Exit
     done
   with Exit -> ());
  !last_cut_point

type preparation = {
  first_kept_entry_id : string;
  messages_to_summarize : Coding_messages.session_message list;
  previous_summary : string option;
}

let prepare_compaction (messages_entries : Coding_entries.t list) (s : settings) :
    preparation option =
  let previous_summary =
    match messages_entries with
    | Coding_entries.Compaction c :: _ -> Some c.summary
    | _ -> None
  in
  (* A compaction marker is always first in this list, and its summary is
     carried forward explicitly, so it must not be summarised again. *)
  let candidates =
    match previous_summary with
    | Some _ -> (match messages_entries with [] -> [] | _ :: tl -> tl)
    | None -> messages_entries
  in
  match find_cut_point candidates ~keep_recent_tokens:s.keep_recent_tokens with
  | None -> None
  | Some cut ->
      let head = List.filteri (fun i _ -> i < cut) candidates in
      let messages_to_summarize =
        List.filter_map (fun e -> Coding_traversal.entry_to_message e) head
      in
      if messages_to_summarize = [] then None
      else
        Some
          {
            first_kept_entry_id = Coding_entries.id (List.nth candidates cut);
            messages_to_summarize;
            previous_summary;
          }

(* Tool results dominate the context but matter least to a summary, so they are
   clipped before being handed to the summarizer. *)
let tool_result_max_chars = 2000

let truncate_text (text : string) (max_chars : int) : string =
  if String.length text <= max_chars then text
  else
    let dropped = String.length text - max_chars in
    Printf.sprintf "%s\n\n[... %d more characters truncated]"
      (String.sub text 0 max_chars)
      dropped

let serialize_messages_for_compaction (messages : Coding_messages.session_message list) : string =
  let render (m : Coding_messages.session_message) : string option =
    match m with
    | Coding_messages.Msg (Ai_types.User u) ->
        Some (Printf.sprintf "<message role='user'>\n%s\n</message>" u.content)
    | Coding_messages.Msg (Ai_types.Assistant a) ->
        let content = String.trim a.content in
        let content =
          if a.tool_calls = [] then content
          else
            let tool_lines =
              List.map
                (fun (tc : Ai_types.tool_call) ->
                  Printf.sprintf " - %s: %s" tc.name (Yojson.Safe.to_string tc.arguments))
                a.tool_calls
            in
            Printf.sprintf "%s\n<tool_calls>\n%s\n</tool_calls>" content (String.concat "\n" tool_lines)
        in
        Some (Printf.sprintf "<message role='assistant'>\n%s\n</message>" content)
    | Coding_messages.Msg (Ai_types.Tool_result r) ->
        let status = if r.is_error then "failed" else "ok" in
        Some
          (Printf.sprintf "<message role='tool' name='%s' status=%s>\n%s\n</message>" r.tool_name
             status (truncate_text r.content tool_result_max_chars))
    | Coding_messages.Compaction_summary _ -> None
  in
  messages |> List.filter_map render |> String.concat "\n"

let summarization_system_prompt =
  "\nYou are context summarization assistant. Your task is to read conversation between user and AI \
   coding assistant, then produce a concise, structured summary following the exact format specified.\nDo \
   not continue the conversation. Do not respond to any questions in the conversation. Do not call tools, \
   tools are not available. Do not try to explore more to gather more information. Your only task is to \
   output the structured summary.\n"

let summarization_prompt =
  "\nUse this exact format\n\n## Goal\n\n## Constraints & Preferences\n\n## Progress\n\n### Done\n\n### In \
   Progress\n\n### Blocked\n\n### Key Decisions\n\n## Next Steps\n\n## Critical Context\n- [Any file paths, \
   function names, error messages, or context needed to continue]\n\n"

let generate_compaction_summary ~(stream_fn : Ai_types.stream_fn)
    ~(model : Ai_types.ai_model) ~(messages_to_summarize : Coding_messages.session_message list)
    ?(custom_instructions : string option) ?(previous_summary : string option)
    ~(signal : Ai_cancellation.t option) () : string Lwt.t =
  let conversation_text = serialize_messages_for_compaction messages_to_summarize in
  let prompt = ref (summarization_prompt ^ "\n") in
  (match previous_summary with
  | Some s -> prompt := !prompt ^ Printf.sprintf "<previous-summary>\n%s\n</previous-summary>\n" s
  | None -> ());
  prompt := !prompt ^ Printf.sprintf "<conversation>\n%s\n</conversation>\n" conversation_text;
  (match custom_instructions with
  | Some ci when ci <> "" -> prompt := !prompt ^ "\n\nAdditional Focus: " ^ ci
  | _ -> ());

  let response = ref None in
  let* () =
    stream_fn model
      {
        Ai_types.system = summarization_system_prompt;
        messages = [ Ai_types.User { content = !prompt } ];
        tools = [];
      }
      { Ai_types.default_stream_options with signal }
      (fun ev -> match ev with Ai_types.Done m -> (response := Some m; Lwt.return_unit) | _ -> Lwt.return_unit)
  in

  match !response with
  | None -> Lwt.fail (Failure "Summarization returned no response")
  | Some r -> (
      match r.stop_reason with
      | Some Ai_types.Error ->
          Lwt.fail
            (Failure
               (Printf.sprintf "Summarization failed: %s"
                  (Option.value ~default:"unknown error" r.error_message)))
      | Some Ai_types.Aborted -> Lwt.fail (Failure "Summarization Cancelled")
      | Some Ai_types.Length -> Lwt.fail (Failure "Summarization hit the output token limit")
      | _ ->
          if r.tool_calls <> [] then Lwt.fail (Failure "Summarization attempted to call tool")
          else
            let summary = String.trim r.content in
            if summary = "" then Lwt.fail (Failure "Compaction summarization returned an empty summary")
            else Lwt.return summary)

(* Append the file operations that happened across the summarised stretch, so
   the model knows what it had read or changed without re-reading anything. *)
let format_file_operations (messages : Coding_messages.session_message list) : string =
  let read = ref [] and modified = ref [] in
  List.iter
    (fun m ->
      match m with
      | Coding_messages.Msg (Ai_types.Assistant a) ->
          List.iter
            (fun (tc : Ai_types.tool_call) ->
              match Ai_json.str_opt tc.arguments "path" with
              | Some path ->
                  if tc.name = "read" then read := path :: !read
                  else if tc.name = "write" || tc.name = "edit" then modified := path :: !modified
              | None -> ())
            a.tool_calls
      | _ -> ())
    messages;
  let uniq l = List.sort_uniq compare l in
  let read = uniq !read and modified = uniq !modified in
  let read_only = List.filter (fun p -> not (List.mem p modified)) read in
  let sections = ref [] in
  if read_only <> [] then
    sections := !sections @ [ Printf.sprintf "<read-files>\n%s\n</read-files>" (String.concat "\n" read_only) ];
  if modified <> [] then
    sections :=
      !sections @ [ Printf.sprintf "<modified-files>\n%s\n</modified-files>" (String.concat "\n" modified) ];
  String.concat "\n\n" !sections
