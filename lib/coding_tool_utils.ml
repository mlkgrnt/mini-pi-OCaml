(* Port of coding/tools/utils.py

   Truncation is by bytes, as in the original, but UTF-8 aware: cutting a
   multi-byte character in half would hand the model a replacement character,
   so we snap the cut to a character boundary. *)

exception Tool_error of string

let tool_error msg = raise (Tool_error msg)

let default_max_bytes = 50 * 1024 (* 50 KB, roughly 14 K tokens *)

type truncation_result = {
  output : string;
  truncated : bool;
  total_bytes : int;
  output_bytes : int;
}

let utf8_char_len b =
  if b land 0x80 = 0 then 1
  else if b land 0xE0 = 0xC0 then 2
  else if b land 0xF0 = 0xE0 then 3
  else if b land 0xF8 = 0xF0 then 4
  else 1

let head_cut s max_bytes =
  let len = String.length s in
  let i = ref 0 and last = ref 0 and stop = ref false in
  while (not !stop) && !i < len do
    let l = utf8_char_len (Char.code s.[!i]) in
    if !i + l > max_bytes then stop := true
    else (
      i := !i + l;
      last := !i)
  done;
  String.sub s 0 !last

let tail_cut s max_bytes =
  let len = String.length s in
  let start = ref (max 0 (len - max_bytes)) in
  while !start < len && Char.code s.[!start] land 0xC0 = 0x80 do
    incr start
  done;
  String.sub s !start (len - !start)

type mode = Head | Tail

let truncate ?(max_bytes = default_max_bytes) (content : string) (mode : mode) :
    truncation_result =
  let total_bytes = String.length content in
  if total_bytes <= max_bytes then
    { output = content; truncated = false; total_bytes; output_bytes = total_bytes }
  else
    let output = match mode with Head -> head_cut content max_bytes | Tail -> tail_cut content max_bytes in
    { output; truncated = true; total_bytes; output_bytes = String.length output }

let format_size bytes_count =
  if bytes_count < 1024 then Printf.sprintf "%dB" bytes_count
  else if bytes_count < 1024 * 1024 then Printf.sprintf "%.1fKB" (float_of_int bytes_count /. 1024.0)
  else Printf.sprintf "%.1fMB" (float_of_int bytes_count /. (1024.0 *. 1024.0))

(* ------------------------------------------------------------------ *)
(* Path handling                                                       *)
(* ------------------------------------------------------------------ *)

let to_slashes p = String.map (fun c -> if c = '\\' then '/' else c) p

(* Lexical normalisation. The Python original uses Path.resolve(), which also
   follows symlinks; we deliberately do not, because following links on Windows
   is both slow and the source of surprising escapes. *)
let normalize (p : string) : string =
  let p = to_slashes p in
  let drive, rest =
    if
      String.length p >= 2 && p.[1] = ':'
      && (let c = Char.lowercase_ascii p.[0] in
          c >= 'a' && c <= 'z')
    then (String.sub p 0 2, String.sub p 2 (String.length p - 2))
    else ("", p)
  in
  let absolute = String.length rest > 0 && rest.[0] = '/' in
  let stack =
    List.fold_left
      (fun acc part ->
        match part with
        | "" | "." -> acc
        | ".." -> (match acc with [] -> [] | _ :: tl -> tl)
        | x -> x :: acc)
      [] (String.split_on_char '/' rest)
  in
  let body = String.concat "/" (List.rev stack) in
  let sep = if absolute || drive <> "" then "/" else "" in
  drive ^ sep ^ body

let is_absolute_path p =
  String.length p > 0 && (p.[0] = '/' || (String.length p > 1 && p.[1] = ':'))

(* Resolve [raw] against the workspace and refuse anything that escapes it. *)
let resolve_path ?(cwd = Sys.getcwd ()) (raw : string) : string =
  let workspace = normalize cwd in
  let raw = to_slashes raw in
  let full = if is_absolute_path raw then normalize raw else normalize (workspace ^ "/" ^ raw) in
  if full <> workspace && not (String.starts_with ~prefix:(workspace ^ "/") full) then
    tool_error (Printf.sprintf "Path '%s' is not relative to '%s'" raw workspace)
  else full

(* ------------------------------------------------------------------ *)
(* File helpers                                                        *)
(* ------------------------------------------------------------------ *)

let read_file_text path =
  let ic = open_in_bin path in
  let b = Buffer.create 65536 in
  let chunk = Bytes.create 65536 in
  let rec go () =
    let n = input ic chunk 0 65536 in
    if n > 0 then (
      Buffer.add_subbytes b chunk 0 n;
      go ())
  in
  (try go () with End_of_file -> ());
  close_in ic;
  Buffer.contents b

let rec mkdir_p dir =
  if dir = "" || dir = "." || dir = "/" || Sys.file_exists dir then ()
  else (
    mkdir_p (Filename.dirname dir);
    try Unix.mkdir dir 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ())

let write_file_text path content =
  mkdir_p (Filename.dirname path);
  let oc = open_out_bin path in
  output_string oc content;
  close_out oc

(* Python's str.splitlines(): splits on \n, \r\n and lone \r, and never yields
   a trailing empty element. *)
let split_lines (s : string) : string list =
  let res = ref [] and buf = Buffer.create 64 in
  let n = String.length s in
  let i = ref 0 in
  while !i < n do
    let c = s.[!i] in
    if c = '\n' then (
      res := Buffer.contents buf :: !res;
      Buffer.clear buf;
      incr i)
    else if c = '\r' then (
      res := Buffer.contents buf :: !res;
      Buffer.clear buf;
      if !i + 1 < n && s.[!i + 1] = '\n' then i := !i + 2 else incr i)
    else (
      Buffer.add_char buf c;
      incr i)
  done;
  if Buffer.length buf > 0 then res := Buffer.contents buf :: !res;
  List.rev !res

let count_occurrences haystack needle =
  if needle = "" then 0
  else
    let nh = String.length haystack and nn = String.length needle in
    let count = ref 0 and i = ref 0 in
    while !i + nn <= nh do
      if String.sub haystack !i nn = needle then (
        incr count;
        i := !i + nn)
      else incr i
    done;
    !count

(* Replace the first occurrence only. *)
let replace_first haystack needle replacement =
  let nh = String.length haystack and nn = String.length needle in
  let rec go i =
    if i + nn > nh then None
    else if String.sub haystack i nn = needle then Some i
    else go (i + 1)
  in
  match go 0 with
  | None -> haystack
  | Some i ->
      String.sub haystack 0 i ^ replacement
      ^ String.sub haystack (i + nn) (nh - i - nn)

let command_exists prog =
  let sep = if Sys.win32 then ';' else ':' in
  let paths =
    String.split_on_char sep (Option.value ~default:"" (Sys.getenv_opt "PATH"))
  in
  let exts = if Sys.win32 then [ ".exe"; ".cmd"; ".bat"; "" ] else [ "" ] in
  List.exists
    (fun dir ->
      dir <> ""
      && List.exists (fun ext -> Sys.file_exists (Filename.concat dir (prog ^ ext))) exts)
    paths
