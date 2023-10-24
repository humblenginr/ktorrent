open Core

let (let*) = Lwt.bind

(* Creates a UDP socket*)
let create_udp_socket () = 
  let open Lwt_unix in
  Lwt.return @@ socket PF_INET SOCK_DGRAM 0

let create_tcp_socket () = 
  let open Lwt_unix in
  Lwt.return @@ socket PF_INET SOCK_STREAM 0 

(* Gets the ip address of the url specified*)
let get_inet_addr host port =
  let* addresses= Lwt_unix.getaddrinfo host (Int.to_string port) [] in
  (* let* addresses= Lwt_unix.getaddrinfo "tracker.openbittorrent.com" (Int.to_string port) [] in *)
  print_endline (Int.to_string @@ List.length addresses);
  Lwt.return @@ (List.hd_exn addresses).ai_addr


(* peer_id is a unique id for our client. This the id we use to identify ourselves with the tracker *)
let gen_peer_id () = 
  let peer_id = Stdlib.Bytes.of_string (Time_float.to_string_utc @@ Time_float.now ()) in
  let client_info = Stdlib.Bytes.of_string "-AT0003-" in
  Stdlib.Bytes.blit client_info 0 peer_id 0 (Bytes.length client_info); peer_id

