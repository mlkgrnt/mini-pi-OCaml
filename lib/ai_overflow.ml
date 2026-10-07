(* Port of ai/overflow.py

   A provider reports context overflow as a 400 whose message matches one of
   these patterns. 400 is also used for genuinely malformed requests, which is
   why we pattern match rather than trusting the status code. *)

let overflow_patterns = [ "context_length_exceeded"; "context length exceeded" ]

let lowercase = String.lowercase_ascii

let contains haystack needle =
  let n = String.length needle and h = String.length haystack in
  if n = 0 then true
  else if n > h then false
  else
    let rec go i = if i + n > h then false else if String.sub haystack i n = needle then true else go (i + 1) in
    go 0

let is_context_overflow (message : Ai_types.assistant_message) : bool =
  match (message.stop_reason, message.error_message) with
  | Some Ai_types.Error, Some err ->
      let e = lowercase err in
      List.exists (fun p -> contains e p) overflow_patterns
  | _ -> false
