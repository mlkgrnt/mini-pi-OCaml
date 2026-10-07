(* Port of ai/provider_retry.py *)

(* 4xx generally means the request itself is wrong and retrying is pointless,
   except for these three which describe a transient condition. *)
let retryable_status_codes = [ 408; 409; 429 ]
let default_max_retry_delay_seconds = 60.0

let normalize_headers (headers : (string * string) list) : (string * string) list =
  List.map (fun (k, v) -> (String.lowercase_ascii (String.trim k), String.lowercase_ascii (String.trim v))) headers

let header headers name =
  List.assoc_opt (String.lowercase_ascii name) (normalize_headers headers)

let is_retryable_status ~status_code ~headers =
  match header headers "x-should-retry" with
  | Some "true" -> true
  | Some "false" -> false
  | _ -> List.mem status_code retryable_status_codes || status_code >= 500

(* Transport-level failures (connection reset, DNS failure, timeout) are always
   worth one more attempt. *)
let is_retryable_transport_error (_ : string) = true

let is_retryable_error ?status_code ?headers ?transport_error () =
  if (match header (Option.value ~default:[] headers) "x-should-retry" with
      | Some "true" -> true
      | Some "false" -> false
      | _ -> false)
  then true
  else
    match status_code with
    | Some code -> is_retryable_status ~status_code:code ~headers:(Option.value ~default:[] headers)
    | None -> Option.is_some transport_error

(* Retry-After may be either a number of seconds or an HTTP date. *)
let parse_retry_after_header value =
  let v = String.trim value in
  match float_of_string_opt v with
  | Some f -> Some f
  | None ->
      (* RFC 1123 date. We only handle the numeric case robustly; for a date we
         fall back to a conservative 1 second rather than pulling in a date
         parser for a path that essentially never fires. *)
      Some 1.0

let calculate_retry_delay ?(headers = []) ~attempt ?(max_delay = default_max_retry_delay_seconds) () =
  let h = normalize_headers headers in
  let server_delay =
    match List.assoc_opt "retry-after-ms" h with
    | Some v -> (match float_of_string_opt v with Some f -> Some (f /. 1000.0) | None -> None)
    | None ->
        (match List.assoc_opt "retry-after" h with
        | Some v -> parse_retry_after_header v
        | None -> None)
  in
  match server_delay with
  | Some d ->
      if d > max_delay then
        failwith
          (Printf.sprintf "Server requested %gs retry delay (exceeds %gs cap)" d max_delay)
      else d
  | None ->
      (* exponential backoff with jitter: 1s, 2s, 4s, 8s ... *)
      let base_delay = min (1.0 *. (2.0 ** float_of_int attempt)) max_delay in
      let jitter = 1.0 -. (Random.float 1.0 *. 0.25) in
      base_delay *. jitter
