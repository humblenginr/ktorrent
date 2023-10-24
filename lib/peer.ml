
let (let*) = Lwt.bind

(* Every connection the client makes with the peer has some state that has to be maintained *)

type peer = {
  ip: Ipaddr.V4.t;
  port: int; 

  (* am_choking: int; *)
  (* am_interested: int; *)
  (* peer_choking: int; *)
  (* peer_interested: int; *)

  mutable fd: Lwt_unix.file_descr option;
}

type 'a t = peer constraint 'a = [< `Connected | `Unconnected]

let make ip port : [`Unconnected] t = {
  ip
  ;port

  (* ;am_choking = 1 *)
  (* ;am_interested= 0 *)
  (* ;peer_choking =1 *)
  (* ;peer_interested = 0 *)

  ;fd= None
}

let sexp_of_t t =
let open Core in
Sexp.List ([Sexp.Atom ( Ipaddr.V4.to_string t.ip); Sexp.Atom (Int.to_string t.port)])

let ip t = t.ip
let port t = t.port

let connect (p : [`Unconnected] t ) : [`Connected] t Lwt.t = 
  let open Lwt_unix in
  let* sck = Utils.create_tcp_socket () in
  let addr = ADDR_INET (Unix.inet_addr_of_string ( Ipaddr.V4.to_string p.ip), p.port) in
  let* _ = connect sck addr in
  p.fd <- Some sck;
  print_endline @@ "Connected to peer: " ^ Ipaddr.V4.to_string p.ip;
  Lwt.return @@ p


let handshake_msg_builder peer_id info_hash = 
let res_buffer = Bytes.create 68 in
let open Stdlib.Bytes in 
(* pstrlen *)
let () = set_int8 res_buffer 0 (19) in
(*pstr - protocol identifier*)
let protocol = of_string "BitTorrent protocol" in
let () = blit protocol 0 res_buffer 1 (length protocol) in
(*reserved bytes *)
let () = set_int32_be res_buffer 20 (Int32.of_int 0) in
let () = set_int32_be res_buffer 24 (Int32.of_int 0) in
(*info_hash *)
let () = blit info_hash 0 res_buffer 28 20 in
(* peer_id length exceeds 20 bytes, therefore we are ignoring the extra bytes*)
let () = blit peer_id 0 res_buffer 48 20 in
res_buffer

let handshake (p: [`Connected] t) info_hash peer_id = 
  let open Lwt_unix in
  let open Stdlib.Bytes in 
  let buffer = make 80 (char_of_int 0) in
  let handshake_data = handshake_msg_builder peer_id info_hash in
  let fd = Core.Option.value_exn p.fd in
  let* _ = write fd handshake_data 0 (length handshake_data) in
  print_endline "waiting for handshake response";
  let* _ = read fd buffer 0 (length buffer) in
  (* let p = get_uint8 buffer 0 in *)
  print_endline @@ "Response from the server: " ^ (to_string buffer);

  (* 
     I am able to successfully establish a connection with the client, but the data I get back from the handshake is not what I expect.  
     There might be two problems. 1 -> I might be incorrectly reading the data from the socket, or the client itself might not be sending 
     proper response.
   *)

  Lwt.return ()

