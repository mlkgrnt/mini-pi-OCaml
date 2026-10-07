(* Port of coding/session_manager/manager.py

   Session files live under ~/.mini-pi/sessions/--<sanitized cwd>--/. A file is
   only created once the first assistant message lands, so abandoned sessions
   never leave a stub behind. *)

let base_session_dir () =
  Filename.concat (Filename.concat (Coding_auth.home_dir ()) ".mini-pi") "sessions"

(* re.sub(r"[/:]+", "-", posix_path).strip("-") or "root" *)
let sanitize_cwd (cwd : string) : string =
  let posix = Coding_tool_utils.to_slashes cwd in
  let buf = Buffer.create (String.length posix) in
  let in_run = ref false in
  String.iter
    (fun c ->
      if c = '/' || c = ':' then (
        if not !in_run then (
          Buffer.add_char buf '-';
          in_run := true))
      else (
        in_run := false;
        Buffer.add_char buf c))
    posix;
  let s = Buffer.contents buf in
  let s = String.trim s in
  (* Python's strip("-") removes leading and trailing dashes. *)
  let start = ref 0 and stop = ref (String.length s) in
  while !start < !stop && s.[!start] = '-' do
    incr start
  done;
  while !stop > !start && s.[!stop - 1] = '-' do
    decr stop
  done;
  let trimmed = String.sub s !start (!stop - !start) in
  if trimmed = "" then "root" else trimmed

let default_session_dir ?(cwd = "") () : string =
  let cwd = if cwd = "" then Sys.getcwd () else cwd in
  Filename.concat (base_session_dir ()) ("--" ^ sanitize_cwd cwd ^ "--")

type file_metadata = { updated_at : string; id : string; title : string option }

let read_file_text = Coding_tool_utils.read_file_text

let extract_first_user_message (file_path : string) : string option =
  try
    let lines = Coding_tool_utils.split_lines (read_file_text file_path) in
    let rec go = function
      | [] -> None
      | line :: rest -> (
          match Yojson.Safe.from_string line with
          | exception _ -> go rest
          | `Assoc _ as j
            when Ai_json.str_opt j "type" = Some "message" -> (
              match Ai_json.member "message" j with
              | Some m when Ai_json.str_opt m "role" = Some "user" ->
                  let content = Ai_json.str m "content" "" in
                  if content <> "" then Some (String.trim (String.concat " " (String.split_on_char ' ' content |> List.filter (fun s -> s <> ""))))
                  else go rest
              | _ -> go rest)
          | _ -> go rest)
    in
    go lines
  with _ -> None

let jsonl_files dir = try Sys.readdir dir with _ -> [||]

let list_sessions ?(session_dir = "") () : file_metadata list =
  let dir = if session_dir = "" then default_session_dir () else session_dir in
  if not (Sys.file_exists dir && Sys.is_directory dir) then []
  else
    let rows =
      Array.to_list (jsonl_files dir)
      |> List.filter (fun f -> Filename.check_suffix f ".jsonl")
      |> List.map (fun f ->
             let path = Filename.concat dir f in
             let mtime = try (Unix.stat path).Unix.st_mtime with _ -> 0.0 in
             let first_user_msg = extract_first_user_message path in
             let title =
               match first_user_msg with
               | None -> None
               | Some m -> Some (if String.length m > 25 then String.sub m 0 25 ^ "..." else m)
             in
             {
               updated_at = Coding_entries.iso_local_of_unix mtime;
               id = Filename.remove_extension f;
               title;
             })
    in
    (* newest first *)
    List.sort
      (fun a b -> compare b.updated_at a.updated_at)
      rows

(* ------------------------------------------------------------------ *)

type t = {
  session_id : string;
  session_file_path : string;
  cwd : string;
  mutable entries : Coding_entries.t list;
  entries_mapping : (string, Coding_entries.t) Hashtbl.t;
  mutable is_session_file_exist : bool;
  mutable leaf_id : string option;
}

let generate_session_id () =
  let tm = Unix.localtime (Unix.gettimeofday ()) in
  Printf.sprintf "%04d%02d%02d_%02d%02d%02d_%s" (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1)
    tm.Unix.tm_mday tm.Unix.tm_hour tm.Unix.tm_min tm.Unix.tm_sec (Coding_entries.random_hex 4)

let compute_leaf (entries : Coding_entries.t list) =
  if List.length entries > 1 then
    Some (Coding_entries.id (List.nth entries (List.length entries - 1)))
  else None

let make ~session_id ~session_file_path ~cwd ~entries ~is_session_file_exist =
  {
    session_id;
    session_file_path;
    cwd;
    entries;
    entries_mapping = Coding_traversal.entries_by_id entries;
    is_session_file_exist;
    leaf_id = compute_leaf entries;
  }

let new_session ?(cwd = "") ?(session_id = "") () : t =
  let resolved_cwd = if cwd = "" then Sys.getcwd () else cwd in
  let session_id = if session_id = "" then generate_session_id () else session_id in
  let session_file_path =
    Filename.concat (default_session_dir ~cwd:resolved_cwd ()) (session_id ^ ".jsonl")
  in
  let header =
    Coding_entries.Header
      {
        id = session_id;
        timestamp = Coding_entries.current_timestamp ();
        cwd = resolved_cwd;
      }
  in
  make ~session_id ~session_file_path ~cwd:resolved_cwd ~entries:[ header ]
    ~is_session_file_exist:false

let read_session_file (file_path : string) : t =
  if not (Sys.file_exists file_path) then
    failwith (Printf.sprintf "Session file not found: %s" file_path);
  let lines = Coding_tool_utils.split_lines (read_file_text file_path) in
  let entries =
    List.filter_map
      (fun l ->
        match Coding_entries.of_json_line l with Some e -> Some e | None -> None)
      lines
  in
  match entries with
  | Coding_entries.Header h :: _ ->
      make ~session_id:h.id ~session_file_path:file_path ~cwd:h.cwd ~entries
        ~is_session_file_exist:true
  | _ -> failwith (Printf.sprintf "Invalid session file at %s" file_path)

let contains_sub (s : string) (sub : string) =
  let n = String.length sub and m = String.length s in
  if n = 0 then true
  else
    let rec go i = i + n <= m && (String.sub s i n = sub || go (i + 1)) in
    go 0

let search_session (search_prefix : string) (cwd : string) : t option =
  let dir = default_session_dir ~cwd () in
  let exact = Filename.concat dir (search_prefix ^ ".jsonl") in
  if Sys.file_exists exact then Some (read_session_file exact)
  else
    let candidates =
      Array.to_list (jsonl_files dir)
      |> List.filter (fun f ->
             Filename.check_suffix f ".jsonl"
             && contains_sub (Filename.remove_extension f) search_prefix)
    in
    match candidates with
    | [ f ] -> Some (read_session_file (Filename.concat dir f))
    | _ -> None

(* Only persisted once a successful assistant message exists: a file containing
   just a header or a user message is not worth keeping. *)
let persist (t : t) (entry : Coding_entries.t) =
  let has_assistant =
    List.exists
      (fun e ->
        match e with
        | Coding_entries.Message m -> (
            match Coding_messages.as_assistant m.message with
            | Some a ->
                a.stop_reason <> Some Ai_types.Error && a.stop_reason <> Some Ai_types.Aborted
            | None -> false)
        | _ -> false)
      t.entries
  in
  if has_assistant then (
    Coding_tool_utils.mkdir_p (Filename.dirname t.session_file_path);
    if not t.is_session_file_exist then (
      let oc = open_out_bin t.session_file_path in
      List.iter (fun e -> output_string oc (Coding_entries.to_json_line e)) t.entries;
      close_out oc;
      t.is_session_file_exist <- true)
    else
      let oc = open_out_gen [ Open_append; Open_binary ] 0o644 t.session_file_path in
      output_string oc (Coding_entries.to_json_line entry);
      close_out oc)

let append_entry (t : t) (entry : Coding_entries.t) =
  t.entries <- t.entries @ [ entry ];
  Hashtbl.replace t.entries_mapping (Coding_entries.id entry) entry;
  if not (Coding_entries.is_header entry) then t.leaf_id <- Some (Coding_entries.id entry);
  persist t entry

let append_message (t : t) (message : Coding_messages.session_message) : string =
  let entry =
    Coding_entries.Message
      {
        id = Coding_entries.new_entry_id ();
        timestamp = Coding_entries.current_timestamp ();
        parent_id = t.leaf_id;
        message;
      }
  in
  append_entry t entry;
  Coding_entries.id entry

let append_compaction (t : t) ~(summary : string) ~(first_kept_entry_id : string) : string =
  let entry =
    Coding_entries.Compaction
      {
        id = Coding_entries.new_entry_id ();
        timestamp = Coding_entries.current_timestamp ();
        parent_id = t.leaf_id;
        summary;
        first_kept_entry_id;
      }
  in
  append_entry t entry;
  Coding_entries.id entry

let branch (t : t) (entry_id : string) =
  if not (Hashtbl.mem t.entries_mapping entry_id) then
    failwith (Printf.sprintf "Entry %s not found" entry_id);
  t.leaf_id <- Some entry_id

let build_session_context (t : t) : Coding_traversal.session_context =
  Coding_traversal.build_session_context t.entries ~leaf_id:t.leaf_id

let rewind_entries (t : t) = Coding_traversal.get_rewind_entries t.entries t.leaf_id
let get_active_branch (t : t) = Coding_traversal.branch_by_leaf_id t.entries t.leaf_id
