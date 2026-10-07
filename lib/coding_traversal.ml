(* Port of coding/session_manager/traversal.py

   Walking the entry tree: from a leaf back to the header is the active branch;
   rendering that branch to messages is the session context. *)

exception Session_tree_error of string

let entries_by_id (entries : Coding_entries.t list) : (string, Coding_entries.t) Hashtbl.t =
  let tbl = Hashtbl.create (List.length entries) in
  List.iter
    (fun e ->
      let id = Coding_entries.id e in
      if Hashtbl.mem tbl id then
        raise (Session_tree_error (Printf.sprintf "Duplicate entry '%s' found" id));
      Hashtbl.replace tbl id e)
    entries;
  tbl

let branch_by_leaf_id (entries : Coding_entries.t list) (leaf_id : string option) :
    Coding_entries.t list =
  match leaf_id with
  | None -> []
  | Some leaf ->
      let tbl = entries_by_id entries in
      let acc = ref [] and seen = ref [] and current = ref (Some leaf) and stop = ref false in
      while not !stop do
        match !current with
        | None -> stop := true
        | Some cid ->
            if List.mem cid !seen then
              raise (Session_tree_error (Printf.sprintf "Cycle detected at entry %s" cid));
            (match Hashtbl.find_opt tbl cid with
            | None -> raise (Session_tree_error (Printf.sprintf "Missing session entry: %s" cid))
            | Some entry ->
                seen := cid :: !seen;
                acc := entry :: !acc;
                if Coding_entries.is_header entry then stop := true
                else current := Coding_entries.parent_id entry)
      done;
      !acc

type session_context = {
  messages : Coding_messages.session_message list;
  messages_entries : Coding_entries.t list;
}

let entry_to_message (e : Coding_entries.t) : Coding_messages.session_message option =
  match e with
  | Coding_entries.Message m -> Some m.message
  | Coding_entries.Compaction c -> Some (Coding_messages.Compaction_summary c.summary)
  | Coding_entries.Header _ -> None

let build_session_context (entries : Coding_entries.t list) ~(leaf_id : string option) :
    session_context =
  let branch = branch_by_leaf_id entries leaf_id in
  let arr = Array.of_list branch in
  let n = Array.length arr in

  let latest_compaction_index = ref None in
  for i = n - 1 downto 0 do
    if !latest_compaction_index = None then
      match arr.(i) with
      | Coding_entries.Compaction _ -> latest_compaction_index := Some i
      | _ -> ()
  done;

  let messages_entries = ref [] in

  (match !latest_compaction_index with
  | None -> ()
  | Some ci -> (
      let compaction_entry = arr.(ci) in
      messages_entries := compaction_entry :: !messages_entries;
      let first_kept =
        match compaction_entry with
        | Coding_entries.Compaction c -> c.first_kept_entry_id
        | _ -> ""
      in
      (* Messages between the compaction's keep-point and the compaction itself
         survive as the retained tail. *)
      let found = ref false in
      for i = 0 to ci - 1 do
        let e = arr.(i) in
        if Coding_entries.id e = first_kept then found := true;
        if !found then
          match e with
          | Coding_entries.Message _ -> messages_entries := !messages_entries @ [ e ]
          | _ -> ()
      done));

  let tail_start = match !latest_compaction_index with None -> 0 | Some ci -> ci + 1 in
  for i = tail_start to n - 1 do
    match arr.(i) with
    | Coding_entries.Message _ -> messages_entries := !messages_entries @ [ arr.(i) ]
    | _ -> ()
  done;

  let messages =
    List.map
      (fun e ->
        match entry_to_message e with
        | Some m -> m
        | None -> raise (Failure "entry has no corresponding message"))
      !messages_entries
  in

  { messages; messages_entries = !messages_entries }

(* User messages that can serve as rewind targets. Messages retained before the
   latest compaction are deliberately excluded: rewinding past a compaction
   would resurrect a summary that no longer describes the branch. *)
let get_rewind_entries (entries : Coding_entries.t list) (leaf_id : string option) :
    Coding_entries.t list =
  let branch = branch_by_leaf_id entries leaf_id in
  let arr = Array.of_list branch in
  let n = Array.length arr in
  let latest_compaction_index = ref None in
  for i = n - 1 downto 0 do
    if !latest_compaction_index = None then
      match arr.(i) with
      | Coding_entries.Compaction _ -> latest_compaction_index := Some i
      | _ -> ()
  done;
  let tail_start = match !latest_compaction_index with None -> 0 | Some ci -> ci + 1 in
  let targets = ref [] in
  for i = tail_start to n - 1 do
    match arr.(i) with
    | Coding_entries.Message m when Coding_messages.is_user m.message -> targets := arr.(i) :: !targets
    | _ -> ()
  done;
  List.rev !targets
