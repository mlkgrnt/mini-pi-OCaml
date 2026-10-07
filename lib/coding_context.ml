(* Port of coding/context.py

   Loads AGENTS.md from the workspace root and any skills under
   .agents/skills, then renders them into the system prompt. *)

let read_file_text = Coding_tool_utils.read_file_text

type project_context_file = { path : string; content : string }
type skill = { name : string; description : string; path : string; content : string }

let warn fmt = Printf.ksprintf (fun s -> prerr_endline s) fmt

let discover_project_context ?(cwd = Sys.getcwd ()) () : project_context_file list =
  let candidates = [ Filename.concat cwd "AGENTS.md" ] in
  List.filter_map
    (fun path ->
      if not (Sys.file_exists path && not (Sys.is_directory path)) then None
      else
        match read_file_text path with
        | exception exn ->
            warn "[Warning] could not read context file from  %s: %s" path (Printexc.to_string exn);
            None
        | content -> Some { path; content })
    candidates

let format_project_context (files : project_context_file list) : string =
  if files = [] then ""
  else
    let lines = ref [ "\n\n<project_context>"; "Project Specific Instructions and Guidelines:" ] in
    List.iter
      (fun (f : project_context_file) ->
        lines := !lines @ [ Printf.sprintf "<project_instructions path='%s'>" f.path ];
        lines := !lines @ [ String.trim f.content ];
        lines := !lines @ [ "</project_instructions>\n" ])
      files;
    lines := !lines @ [ "</project_context>" ];
    String.concat "\n" !lines

(* Minimal YAML front matter: [--- ... ---] followed by the body. Only the flat
   key: value pairs this format actually uses are understood. *)
let parse_skill_file (path : string) : skill option =
  match read_file_text path with
  | exception exn ->
      warn "[Warning] could not read skill at '%s: %s'" path (Printexc.to_string exn);
      None
  | raw ->
      if String.trim raw = "" then None
      else
        let dir_name = Filename.basename (Filename.dirname path) in
        let name = ref dir_name and description = ref "No description provided" and body = ref (String.trim raw) in
        (* Detect a leading --- fence delimited block. *)
        let lines = Coding_tool_utils.split_lines raw in
        (match lines with
        | "---" :: rest -> (
            let rec split acc = function
              | [] -> None
              | "---" :: tail -> Some (List.rev acc, tail)
              | l :: tail -> split (l :: acc) tail
            in
            match split [] rest with
            | Some (meta, body_lines) ->
                List.iter
                  (fun line ->
                    match String.index_opt line ':' with
                    | Some i ->
                        let key = String.trim (String.sub line 0 i) in
                        let value = String.trim (String.sub line (i + 1) (String.length line - i - 1)) in
                        if key = "name" then name := value
                        else if key = "description" then description := value
                    | None -> ())
                  meta;
                body := String.trim (String.concat "\n" body_lines)
            | None -> ())
        | _ -> ());
        Some { name = !name; description = !description; path; content = !body }

let discover_skills ?(cwd = Sys.getcwd ()) () : skill list =
  let skill_dir = Filename.concat (Filename.concat cwd ".agents") "skills" in
  if not (Sys.file_exists skill_dir && Sys.is_directory skill_dir) then []
  else
    let children = try Sys.readdir skill_dir with _ -> [||] in
    Array.to_list children
    |> List.filter_map (fun child ->
           let full = Filename.concat skill_dir child in
           let candidate =
             if Sys.file_exists full && Sys.is_directory full then Some (Filename.concat full "SKILL.md")
             else if child = "SKILL.md" then Some full
             else None
           in
           match candidate with
           | Some c when Sys.file_exists c && not (Sys.is_directory c) -> parse_skill_file c
           | _ -> None)

let format_skills (skills : skill list) : string =
  if skills = [] then ""
  else
    let lines =
      ref
        [
          "\n\nThe following skills provide specialized instructions for a specific tasks. \
           Read the full skill file using the `read` tool when task matches its description";
          "<available_skills>\n";
        ]
    in
    List.iter
      (fun s ->
        lines :=
          !lines
          @ [
              Printf.sprintf "<skill>\n<name>%s</name>\n<description>%s</description>\n<location>%s</location>\n</skill>\n"
                s.name s.description s.path;
            ])
      skills;
    lines := !lines @ [ "</available_skills>" ];
    String.concat "\n" !lines
