(* Port of coding/modes/rpc/{rpc,output,extension_ui,types}.py

   The wire format is the contract with the original TypeScript TUI, so the
   field names and the shape of every payload here are fixed by
   coding/tui/src/types/rpc.ts, not by taste.

   stdout carries nothing but newline-delimited JSON; all diagnostics go to
   stderr. *)

open Lwt.Syntax

let emit (j : Yojson.Safe.t) =
  output_string stdout (Yojson.Safe.to_string j);
  output_char stdout '\n';
  flush stdout

let write_event (e : Coding_events.t) : unit Lwt.t =
  emit (Coding_events.to_json e);
  Lwt.return_unit

let opt_string = function Some s -> `String s | None -> `Null

let random_id () = Coding_entries.random_hex 6

(* ------------------------------------------------------------------ *)
(* Requests                                                            *)
(* ------------------------------------------------------------------ *)

type request = {
  id : string option;
  kind : string;
  message : string;
  custom_instructions : string option;
  session_id : string;
  entry_id : string;
  provider : string;
  key : string;
  model_ref : string;
}

let known_types =
  [
    "prompt";
    "steer";
    "follow_up";
    "compact";
    "resume";
    "rewind";
    "abort";
    "new_session";
    "get_state";
    "list_sessions";
    "get_rewind_targets";
    "get_extension_commands";
    "login";
    "logout";
    "set_default_model";
  ]

let parse_request (j : Yojson.Safe.t) : request =
  let kind =
    match Ai_json.str_opt j "type" with
    | Some t when List.mem t known_types -> t
    | Some t -> failwith ("Unknown request type: " ^ t)
    | None -> failwith "Request has no type"
  in
  {
    id = Ai_json.str_opt j "id";
    kind;
    message = Ai_json.str j "message" "";
    custom_instructions = Ai_json.str_opt j "custom_instructions";
    session_id = Ai_json.str j "session_id" "";
    entry_id = Ai_json.str j "entry_id" "";
    provider = Ai_json.str j "provider" "";
    key = Ai_json.str j "key" "";
    model_ref = Ai_json.str j "model_ref" "";
  }

(* ------------------------------------------------------------------ *)
(* Responses                                                           *)
(* ------------------------------------------------------------------ *)

let empty_success ~(id : string option) ~(request_type : string) : Yojson.Safe.t =
  `Assoc
    [
      ("id", opt_string id);
      ("type", `String "response");
      ("request_type", `String request_type);
      ("success", `Bool true);
    ]

let payload_response ~(id : string option) ~(request_type : string) ~(data : Yojson.Safe.t) :
    Yojson.Safe.t =
  `Assoc
    [
      ("id", opt_string id);
      ("type", `String "response");
      ("request_type", `String request_type);
      ("success", `Bool true);
      ("data", data);
    ]

let error_response ~(id : string option) ~(request_type : string) ~(error : string) :
    Yojson.Safe.t =
  `Assoc
    [
      ("id", opt_string id);
      ("type", `String "response");
      ("request_type", `String request_type);
      ("success", `Bool false);
      ("error", `String error);
    ]

let session_data ~(session_id : string) (messages : Coding_messages.session_message list) :
    Yojson.Safe.t =
  `Assoc
    [
      ("session_id", `String session_id);
      ("messages", `List (List.map Coding_messages.to_json messages));
    ]

(* ------------------------------------------------------------------ *)
(* Extension UI                                                        *)
(* ------------------------------------------------------------------ *)

let pending_ui : (string, (string option * bool) Lwt.u) Hashtbl.t = Hashtbl.create 4

let rpc_ui : Coding_extensions.ui =
  {
    select =
      (fun title options ->
        let id = random_id () in
        let promise, wakener = Lwt.wait () in
        Hashtbl.replace pending_ui id wakener;
        emit
          (`Assoc
             [
               ("type", `String "extension_ui_request");
               ("id", `String id);
               ( "payload",
                 `Assoc
                   [
                     ("method", `String "select");
                     ("title", `String title);
                     ("options", `List (List.map (fun o -> `String o) options));
                   ] );
             ]);
        let* value, cancelled = promise in
        Hashtbl.remove pending_ui id;
        if cancelled then Lwt.return_none else Lwt.return value);
    notify =
      (fun message level ->
        emit
          (`Assoc
             [
               ("type", `String "extension_ui_request");
               ("id", `String (random_id ()));
               ( "payload",
                 `Assoc
                   [
                     ("method", `String "notify");
                     ("message", `String message);
                     ("notify_type", `String level);
                   ] );
             ]));
  }

let resolve_ui_response (j : Yojson.Safe.t) =
  match Ai_json.str_opt j "id" with
  | None -> ()
  | Some id -> (
      match Hashtbl.find_opt pending_ui id with
      | None -> ()
      | Some wakener ->
          let cancelled = match Ai_json.bool_opt j "cancelled" with Some b -> b | None -> false in
          let value = Ai_json.str_opt j "value" in
          (* Removed before waking so a duplicate response cannot resolve twice. *)
          Hashtbl.remove pending_ui id;
          Lwt.wakeup_later wakener (value, cancelled))

(* ------------------------------------------------------------------ *)
(* Request handling                                                    *)
(* ------------------------------------------------------------------ *)

let handle_request (req : request) (rt : Coding_session_runtime.t) : unit Lwt.t =
  let session = rt.Coding_session_runtime.session in
  let csm = session.Coding_session.chat_session_manager in

  match req.kind with
  | "prompt" ->
      (* Acknowledge first: the TUI must stay responsive while the run streams
         events back over the same channel. *)
      emit (empty_success ~id:req.id ~request_type:"prompt");
      Coding_session.prompt session req.message
  | "steer" ->
      let* () = Coding_session.steer session req.message in
      emit (empty_success ~id:req.id ~request_type:"steer");
      Lwt.return_unit
  | "follow_up" ->
      let* () = Coding_session.follow_up session req.message in
      emit (empty_success ~id:req.id ~request_type:"follow_up");
      Lwt.return_unit
  | "compact" ->
      let* () =
        Coding_session.compact session ~reason:Coding_events.Manual
          ?custom_instructions:req.custom_instructions ()
      in
      emit (empty_success ~id:req.id ~request_type:"compact");
      Lwt.return_unit
  | "rewind" ->
      let* messages = Coding_session.rewind_to session req.entry_id in
      emit
        (payload_response ~id:req.id ~request_type:"rewind"
           ~data:(session_data ~session_id:csm.session_id messages));
      Lwt.return_unit
  | "login" ->
      Coding_auth.set_api_key_to_auth req.provider req.key;
      emit (empty_success ~id:req.id ~request_type:"login");
      Lwt.return_unit
  | "logout" ->
      ignore (Coding_auth.remove_api_key_from_auth req.provider);
      emit (empty_success ~id:req.id ~request_type:"logout");
      Lwt.return_unit
  | "set_default_model" ->
      let ai_model = Ai_registry.get_model req.model_ref in
      (match Ai_registry.get_api_key ai_model.provider with
      | Some _ -> ()
      | None -> failwith (Printf.sprintf "API key missing for provider: %s" ai_model.provider));
      Coding_settings.set_default_model req.model_ref;
      Coding_session.set_model session ai_model;
      emit (empty_success ~id:req.id ~request_type:"set_default_model");
      Lwt.return_unit
  | "list_sessions" ->
      let rows = Coding_session_manager.list_sessions () in
      emit
        (payload_response ~id:req.id ~request_type:"list_sessions"
           ~data:
             (`Assoc
                [
                  ( "rows",
                    `List
                      (List.map
                         (fun (r : Coding_session_manager.file_metadata) ->
                           `Assoc
                             [
                               ("updated_at", `String r.updated_at);
                               ("id", `String r.id);
                               ("title", match r.title with Some t -> `String t | None -> `Null);
                             ])
                         rows) );
                ]));
      Lwt.return_unit
  | "get_state" ->
      emit
        (payload_response ~id:req.id ~request_type:"get_state"
           ~data:
             (`Assoc
                [
                  ("model", `String session.Coding_session.config.model.Ai_types.name);
                  ("session_id", `Null);
                  ("session_name", `Null);
                ]));
      Lwt.return_unit
  | "new_session" ->
      let* () = Coding_session_runtime.new_session rt in
      emit
        (payload_response ~id:req.id ~request_type:"new_session"
           ~data:
             (session_data
                ~session_id:
                  rt.Coding_session_runtime.session.Coding_session.chat_session_manager.session_id
                []));
      Lwt.return_unit
  | "resume" ->
      let* () = Coding_session_runtime.switch_session rt req.session_id in
      let s = rt.Coding_session_runtime.session in
      emit
        (payload_response ~id:req.id ~request_type:"resume"
           ~data:
             (session_data ~session_id:s.Coding_session.chat_session_manager.session_id
                s.Coding_session.harness.Agent_harness.messages));
      Lwt.return_unit
  | "get_rewind_targets" ->
      let* targets = Coding_session.rewind_targets session in
      emit
        (payload_response ~id:req.id ~request_type:"get_rewind_targets"
           ~data:
             (`Assoc
                [
                  ( "targets",
                    `List
                      (List.map
                         (fun (t : Coding_session.rewind_target) ->
                           `Assoc [ ("entry_id", `String t.entry_id); ("text", `String t.text) ])
                         targets) );
                ]));
      Lwt.return_unit
  | "get_extension_commands" ->
      let commands =
        match session.Coding_session.config.extension_runtime with
        | Some er -> Coding_extensions.get_all_commands er
        | None -> []
      in
      emit
        (payload_response ~id:req.id ~request_type:"get_extension_commands"
           ~data:
             (`Assoc
                [
                  ( "commands",
                    `List
                      (List.map
                         (fun (c : Coding_extensions.command) ->
                           `Assoc [ ("name", `String c.name); ("description", `String c.description) ])
                         commands) );
                ]));
      Lwt.return_unit
  | "abort" ->
      Coding_session.cancel session;
      emit (empty_success ~id:req.id ~request_type:"abort");
      Lwt.return_unit
  | other -> failwith ("Unhandled request type: " ^ other)

(* ------------------------------------------------------------------ *)
(* Main loop                                                           *)
(* ------------------------------------------------------------------ *)

let handle_line (line : string) (rt : Coding_session_runtime.t) : unit Lwt.t =
  match Yojson.Safe.from_string line with
  | exception exn ->
      emit
        (error_response ~id:None ~request_type:"parse_error"
           ~error:("Invalid json: " ^ Printexc.to_string exn));
      Lwt.return_unit
  | json -> (
      if Ai_json.str_opt json "type" = Some "extension_ui_response" then (
        resolve_ui_response json;
        Lwt.return_unit)
      else
        match parse_request json with
        | exception exn ->
            emit
              (error_response ~id:(Ai_json.str_opt json "id") ~request_type:"parse_error"
                 ~error:("Invalid request: " ^ Printexc.to_string exn));
            Lwt.return_unit
        | req ->
            Lwt.catch
              (fun () -> handle_request req rt)
              (fun exn ->
                emit
                  (error_response ~id:req.id ~request_type:req.kind
                     ~error:(Printexc.to_string exn));
                Lwt.return_unit))

let run (rt : Coding_session_runtime.t) : unit Lwt.t =
  let session_unsubscribe : (unit -> unit) option ref = ref None in

  let rebind (s : Coding_session.t) =
    (match !session_unsubscribe with Some f -> f () | None -> ());
    (match s.Coding_session.config.extension_runtime with
    | Some er -> Coding_extensions.set_ui er (Some rpc_ui)
    | None -> ());
    session_unsubscribe := Some (Coding_session.subscribe s write_event)
  in

  Coding_session_runtime.set_rebind_session rt rebind;
  rebind rt.Coding_session_runtime.session;

  (* Requests are dispatched as they arrive and never awaited here, so a running
     prompt cannot block /abort or steering on the same channel. *)
  Proc_util.line_stream Unix.stdin
  |> Lwt_stream.iter_s (fun line ->
         if String.trim line = "" then Lwt.return_unit
         else (
           Lwt.async (fun () -> handle_line line rt);
           Lwt.return_unit))
