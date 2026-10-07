(* Port of coding/session_manager/entries.py

   A session is an append-only JSONL file. Every line is one entry: a header,
   a message, or a compaction marker. Entries form a tree via parent_id, which
   is what makes /rewind and /branch possible. *)

let () = Random.self_init ()

let random_hex n =
  let buf = Bytes.create n in
  let hex = "0123456789abcdef" in
  for i = 0 to n - 1 do
    Bytes.set buf i hex.[Random.int 16]
  done;
  Bytes.to_string buf

let new_entry_id () = random_hex 8

(* datetime.now(timezone.utc).isoformat(): microseconds, +00:00 offset. *)
let current_timestamp () =
  let t = Unix.gettimeofday () in
  let tm = Unix.gmtime t in
  let frac = t -. Float.floor t in
  let micros = int_of_float (Float.round (frac *. 1_000_000.0)) in
  let micros = if micros >= 1_000_000 then 999_999 else micros in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02d.%06d+00:00"
    (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday tm.Unix.tm_hour
    tm.Unix.tm_min tm.Unix.tm_sec micros

(* datetime.fromtimestamp(mtime).isoformat(): local time, naive. Used for the
   session list payload. *)
let iso_local_of_unix t =
  let tm = Unix.localtime t in
  let frac = t -. Float.floor t in
  let micros = int_of_float (Float.round (frac *. 1_000_000.0)) in
  let micros = if micros >= 1_000_000 then 999_999 else micros in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02d.%06d"
    (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday tm.Unix.tm_hour
    tm.Unix.tm_min tm.Unix.tm_sec micros

type t =
  | Header of { id : string; timestamp : string; cwd : string }
  | Message of {
      id : string;
      timestamp : string;
      parent_id : string option;
      message : Coding_messages.session_message;
    }
  | Compaction of {
      id : string;
      timestamp : string;
      parent_id : string option;
      summary : string;
      first_kept_entry_id : string;
    }

let id = function Header h -> h.id | Message m -> m.id | Compaction c -> c.id

let parent_id = function
  | Header _ -> None
  | Message m -> m.parent_id
  | Compaction c -> c.parent_id

let is_header = function Header _ -> true | _ -> false

let to_json (e : t) : Yojson.Safe.t =
  let opt = function Some s -> `String s | None -> `Null in
  match e with
  | Header h ->
      `Assoc
        [
          ("type", `String "header");
          ("id", `String h.id);
          ("timestamp", `String h.timestamp);
          ("cwd", `String h.cwd);
        ]
  | Message m ->
      `Assoc
        [
          ("type", `String "message");
          ("id", `String m.id);
          ("timestamp", `String m.timestamp);
          ("parent_id", opt m.parent_id);
          ("message", Coding_messages.to_json m.message);
        ]
  | Compaction c ->
      `Assoc
        [
          ("type", `String "compaction");
          ("id", `String c.id);
          ("timestamp", `String c.timestamp);
          ("parent_id", opt c.parent_id);
          ("summary", `String c.summary);
          ("first_kept_entry_id", `String c.first_kept_entry_id);
        ]

exception Session_entry_error of string

let of_json (j : Yojson.Safe.t) : t =
  let g name = Ai_json.str_opt j name in
  match g "type" with
  | Some "header" ->
      Header
        {
          id = Option.value ~default:(new_entry_id ()) (g "id");
          timestamp = Option.value ~default:(current_timestamp ()) (g "timestamp");
          cwd = Option.value ~default:"" (g "cwd");
        }
  | Some "message" -> (
      match Ai_json.member "message" j with
      | Some m ->
          Message
            {
              id = Option.value ~default:(new_entry_id ()) (g "id");
              timestamp = Option.value ~default:(current_timestamp ()) (g "timestamp");
              parent_id = g "parent_id";
              message = Coding_messages.of_json m;
            }
      | None -> raise (Session_entry_error "message entry without message"))
  | Some "compaction" ->
      Compaction
        {
          id = Option.value ~default:(new_entry_id ()) (g "id");
          timestamp = Option.value ~default:(current_timestamp ()) (g "timestamp");
          parent_id = g "parent_id";
          summary = Option.value ~default:"" (g "summary");
          first_kept_entry_id = Option.value ~default:"" (g "first_kept_entry_id");
        }
  | other ->
      raise
        (Session_entry_error
           (Printf.sprintf "Invalid session entry type: %s" (Option.value ~default:"<none>" other)))

let to_json_line (e : t) : string = Yojson.Safe.to_string (to_json e) ^ "\n"

let of_json_line (line : string) : t option =
  if String.trim line = "" then None
  else
    (* Malformed entries are still a hard error (upstream does the same); the
       option only distinguishes "blank line" from "a real entry". *)
    try Some (of_json (Yojson.Safe.from_string line))
    with exn -> raise (Session_entry_error ("Invalid session entry: " ^ Printexc.to_string exn))
