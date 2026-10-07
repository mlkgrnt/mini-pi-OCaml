(* Port of coding/commands.py

   Built-in slash commands are interpreted by the interface; extension commands
   are interpreted by the session. The interface only needs the list so it can
   render /help and route input. *)

type builtin = { name : string; description : string; argument_hint : string option }

let parse_command (text : string) : string * string =
  let stripped = String.trim text in
  if String.length stripped = 0 || stripped.[0] <> '/' then ("", "")
  else
    let body = String.sub stripped 1 (String.length stripped - 1) in
    match String.index_opt body ' ' with
    | None -> (String.lowercase_ascii (String.trim body), "")
    | Some i ->
        ( String.lowercase_ascii (String.trim (String.sub body 0 i)),
          String.trim (String.sub body (i + 1) (String.length body - i - 1)) )

let builtin_slash_commands : builtin list =
  [
    { name = "exit"; description = "Quit the application"; argument_hint = None };
    { name = "clear"; description = "Start a fresh session"; argument_hint = None };
    { name = "help"; description = "List all available slash commands"; argument_hint = None };
    { name = "session"; description = "Show the active session ID"; argument_hint = None };
    {
      name = "resume";
      description = "List saved sessions or resume a specific session";
      argument_hint = Some "<session_id>";
    };
    {
      name = "compact";
      description = "Compact conversation history with optional focus instructions";
      argument_hint = Some "<instructions>";
    };
    {
      name = "login";
      description = "Login to provider using api key";
      argument_hint = Some "<provider> <key>";
    };
    (* The CLI has no implementation for the following yet. *)
    {
      name = "rewind";
      description = "Rewind conversation to a previous user message";
      argument_hint = None;
    };
    { name = "logout"; description = "Remove the api key for provider"; argument_hint = Some "<provider>" };
    {
      name = "model";
      description = "Set the default model across all sessions";
      argument_hint = Some "<model_ref>";
    };
  ]
