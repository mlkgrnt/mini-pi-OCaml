(* Port of agent/queue.py

   Steering messages are injected between turns of the current run; follow-up
   messages only start a new run after the current one finishes. *)

type t = { mutable steering : string list; mutable follow_up : string list }

let create () = { steering = []; follow_up = [] }

let pending_count q = List.length q.steering + List.length q.follow_up

let steer q msg = q.steering <- q.steering @ [ msg ]
let follow_up q msg = q.follow_up <- q.follow_up @ [ msg ]

let drain_steering q =
  let msgs = q.steering in
  q.steering <- [];
  msgs

let drain_follow_up q =
  let msgs = q.follow_up in
  q.follow_up <- [];
  msgs

let clear q =
  q.steering <- [];
  q.follow_up <- []
