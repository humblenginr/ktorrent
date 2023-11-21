open Core

let (let*) = Lwt.bind

(* Creates a UDP socket*)
let create_udp_socket () = 
  let open Lwt_unix in
  Lwt.return @@ socket PF_INET SOCK_DGRAM 0

let create_tcp_socket () = 
  let open Lwt_unix in
  let sck = socket PF_INET SOCK_STREAM 0 in
  setsockopt sck TCP_NODELAY false;
  Lwt.return sck

  (* 
     recv call by default does not get the full requested amount of bytes from the buffer. It rather receives whatever is available from the buffer. 
     the WAITALL message option is not available in Lwt_unix
     This function waits until the requested amount of bytes are received
     *)
let rec receive_from_socket fd len = 
  let open Stdlib.Bytes in
  let open Lwt_unix in 
  let temp = make len (' ') in
  let* res = recv fd temp 0 (length temp) [] in
  let temp = trim temp in
  (* print_endline @@ "requested: " ^ (Int.to_string len) ^ " got: " ^ (Int.to_string res); *)
  if res < len then
  let* b = receive_from_socket fd (len-res) in
  Lwt.return @@ cat temp (b)
  else Lwt.return temp

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

let compute_promise_with_timeout f timeout =  
  let compute_pr = Lwt.map (fun peer -> `Done peer) (f) in
  let timer = Lwt.map (fun () -> `Timeout) (Lwt_unix.sleep timeout) in
  Lwt.pick [compute_pr; timer]

