(* Port of agent/harness.py

   Owns the session message history, the listener list and the cancellation
   signal for a run. Note that the loop works on a copy of the history: the
   harness's own list grows only as it observes Message_end, which keeps a
   failed or cancelled run from leaving half-written state behind. *)

open Lwt.Syntax

type 'a config = {
  stream_fn : Ai_types.stream_fn;
  mutable model : Ai_types.ai_model;
  system : string;
  tools : Agent_tools.t list;
  of_llm : Ai_types.message -> 'a;
  to_llm : 'a list -> Ai_types.message list;
}

type 'a t = {
  config : 'a config;
  mutable messages : 'a list;
  mutable listeners : ('a Agent_events.t -> unit Lwt.t) list;
  mutable cancellation_signal : Ai_cancellation.t option;
  mutable is_running : bool;
  msg_queue_when_running : Agent_queue.t;
}

let create (config : 'a config) (messages : 'a list) : 'a t =
  {
    config;
    messages;
    listeners = [];
    cancellation_signal = None;
    is_running = false;
    msg_queue_when_running = Agent_queue.create ();
  }

let replace_messages (t : 'a t) (messages : 'a list) = t.messages <- messages

let subscribe (t : 'a t) (listener : 'a Agent_events.t -> unit Lwt.t) : unit -> unit =
  t.listeners <- t.listeners @ [ listener ];
  fun () -> t.listeners <- List.filter (fun l -> l != listener) t.listeners

let notify (t : 'a t) (event : 'a Agent_events.t) : unit Lwt.t =
  (match event with
  | Agent_events.Message_end m -> t.messages <- t.messages @ [ m ]
  | _ -> ());
  let snapshot = t.listeners in
  Lwt_list.iter_s
    (fun listener -> Lwt.catch (fun () -> listener event) (fun _ -> Lwt.return_unit))
    snapshot

let continue (t : 'a t) (content : string) : unit Lwt.t =
  let signal = Ai_cancellation.create () in
  t.cancellation_signal <- Some signal;
  t.is_running <- true;

  let run = Agent_loop.run ~stream_fn:t.config.stream_fn ~model:t.config.model
      ~system:t.config.system ~messages:(ref t.messages)
      ~prompts:[ t.config.of_llm (Ai_types.User { content }) ]
      ~tools:t.config.tools ~of_llm:t.config.of_llm ~to_llm:t.config.to_llm
      ~signal:(Some signal)
      ~get_steering_messages:(fun () -> Agent_queue.drain_steering t.msg_queue_when_running)
      ~get_followup_messages:(fun () -> Agent_queue.drain_follow_up t.msg_queue_when_running)
      ~emit:(notify t)
  in

  Lwt.finalize
    (fun () ->
      Lwt.catch
        (fun () -> run)
        (fun exn ->
          (* Surface the failure as a normal message sequence so subscribers see
             a coherent transcript rather than a dangling run. *)
          let last = match List.rev t.messages with m :: _ -> Some m | [] -> None in
          let already_reported =
            match last with
            | Some m -> (
                match t.config.to_llm [ m ] with
                | [ Ai_types.Assistant a ] ->
                    a.stop_reason = Some Ai_types.Error || a.stop_reason = Some Ai_types.Aborted
                | _ -> false)
            | None -> false
          in
          if already_reported then Lwt.return_unit
          else
            let failure =
              Ai_types.assistant ~stop_reason:Ai_types.Error ~error_message:(Printexc.to_string exn) ()
            in
            let fm = t.config.of_llm (Ai_types.Assistant failure) in
            let* () = notify t (Agent_events.Message_start fm) in
            let* () = notify t (Agent_events.Message_end fm) in
            let* () = notify t (Agent_events.Turn_end (failure, [])) in
            notify t (Agent_events.Agent_end [ fm ])))
    (fun () ->
      (match t.cancellation_signal with
      | Some s when s == signal -> t.cancellation_signal <- None
      | _ -> ());
      t.is_running <- false;
      Lwt.return_unit)

let prompt (t : 'a t) (content : string) : unit Lwt.t =
  if t.is_running then
    Lwt.fail
      (Failure "Agent is already running, use msg_queue_when_running to queue messages")
  else continue t content

let cancel (t : 'a t) =
  match t.cancellation_signal with Some s -> Ai_cancellation.cancel s | None -> ()
