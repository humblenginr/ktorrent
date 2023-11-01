
let (let*) = Lwt.bind

let protocol_string = "BitTorrent protocol"

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



(* When Lwt_unix.connect raises an exception, the promise returned by the `connect` function will be rejected with the exception it raised *)
let connect (p : [`Unconnected] t ) : ([`Connected] t) option Lwt.t = 
  let* sck = Utils.create_tcp_socket () in
  let addr = Lwt_unix.ADDR_INET (Unix.inet_addr_of_string ( Ipaddr.V4.to_string p.ip), p.port) in
  try%lwt
  (let* _ = Lwt_unix.connect sck addr in
  p.fd <- Some sck;
  print_endline @@ "Connected to peer: " ^ Ipaddr.V4.to_string p.ip;
  Lwt.return @@ Some p) with _ -> Lwt.return None
  
let build_keep_alive_message = 
  let open Stdlib.Bytes in
  make 4 '0'

let build_choke_message = 
  let open Stdlib.Bytes in
  let buf = create 5 in
  (*length*)
  let () = Stdint.Int32.to_bytes_big_endian (Stdint.Int32.of_int 1) buf 0 in
  (*id*)
  let () = Stdint.Int8.to_bytes_big_endian (Stdint.Int8.of_int 0) buf 4 in
  buf

let build_unchoke_message = 
  let open Stdlib.Bytes in
  let buf = create 5 in
  (*length*)
  let () = Stdint.Int32.to_bytes_big_endian (Stdint.Int32.of_int 1) buf 0 in
  (*id*)
  let () = Stdint.Int8.to_bytes_big_endian (Stdint.Int8.of_int 1) buf 4 in
  buf

let build_interested_message = 
  let open Stdlib.Bytes in
  let buf = create 5 in
  (*length*)
  let () = Stdint.Int32.to_bytes_big_endian (Stdint.Int32.of_int 1) buf 0 in
  (*id*)
  let () = Stdint.Int8.to_bytes_big_endian (Stdint.Int8.of_int 2) buf 4 in
  buf

let build_not_interested_message = 
  let open Stdlib.Bytes in
  let buf = create 5 in
  (*length*)
  let () = Stdint.Int32.to_bytes_big_endian (Stdint.Int32.of_int 1) buf 0 in
  (*id*)
  let () = Stdint.Int8.to_bytes_big_endian (Stdint.Int8.of_int 3) buf 4 in
  buf

let build_have_message piece_index = 
  let open Stdlib.Bytes in
  let buf = create 9 in
  (*length*)
  let () = Stdint.Int32.to_bytes_big_endian (Stdint.Int32.of_int 5) buf 0 in
  (*id*)
  let () = Stdint.Int8.to_bytes_big_endian (Stdint.Int8.of_int 4) buf 4 in
  (*id*)
  let () = Stdint.Int32.to_bytes_big_endian (Stdint.Int32.of_int piece_index) buf 5 in
  buf

let handshake_msg_builder peer_id info_hash = 
let res_buffer = Bytes.create 68 in
let open Stdlib.Bytes in 
(* pstrlen *)
let () = Stdint.Uint8.to_bytes_big_endian (Stdint.Uint8.of_int 19) res_buffer 0 in
(*pstr - protocol identifier*)
let protocol = of_string protocol_string in
let () = blit protocol 0 res_buffer 1 (length protocol) in
(*reserved bytes *)
let reserved_bytes = make 8 (char_of_int 0) in
let () = blit reserved_bytes 0 res_buffer 20 (length reserved_bytes) in
(*info_hash *)
let () = blit info_hash 0 res_buffer 28 20 in
(* peer_id length exceeds 20 bytes, therefore we are ignoring the extra bytes*)
let () = blit peer_id 0 res_buffer 48 20 in
res_buffer

let verify_handshake_response resp =
  if Stdlib.Bytes.length resp <> 68 then false else
  let pstrlen = Stdint.Uint8.to_int @@ Stdint.Uint8.of_bytes_big_endian resp 0 in
  let pstr = Stdlib.Bytes.to_string @@ Stdlib.Bytes.sub resp 1 19 in 
  (* let pid = Stdlib.Byotes.sub resp 48 20 in *)
  Int.equal pstrlen 19 && String.equal pstr protocol_string

let handshake (p: [`Connected] t) info_hash peer_id = 
  let open Lwt_unix in
  let open Stdlib.Bytes in 
  let buffer = make 68 ' ' in
  let handshake_data = handshake_msg_builder peer_id info_hash in
  let fd = Core.Option.value_exn p.fd in
  let* _ = write fd handshake_data 0 (length handshake_data) in
  let* _ = read fd buffer 0 (length buffer) in
  (* let p = get_uint8 buffer 0 in *)
  Lwt.return (verify_handshake_response buffer)
