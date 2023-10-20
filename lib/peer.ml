
let (let*) = Lwt.bind

(* Every connection the client makes with the peer has some state that has to be maintained *)

type peer = {
  ip: string;
  port: int; 

  (* am_choking: int; *)
  (* am_interested: int; *)
  (* peer_choking: int; *)
  (* peer_interested: int; *)

  mutable fd: Lwt_unix.file_descr option;
  id: string;
}

type 'a t = peer constraint 'a = [< `Connected | `Unconnected]

let make ip port id : [`Unconnected] t = {
  ip
  ;port

  (* ;am_choking = 1 *)
  (* ;am_interested= 0 *)
  (* ;peer_choking =1 *)
  (* ;peer_interested = 0 *)

  ;fd= None
  ;id
}

let sexp_of_t t =
let open Core in
Sexp.List ([Sexp.Atom t.ip; Sexp.Atom (Int.to_string t.port)])

let ip t = t.ip
let port t = t.port

let connect (p : [`Unconnected] t ) : [`Connected] t Lwt.t = 
  let open Lwt_unix in
  let* sck = Utils.create_tcp_socket () in
  p.fd <- Some sck;
  let addr = ADDR_INET (Unix.inet_addr_of_string p.ip, p.port) in
  let* _ = connect sck addr in
  Lwt.return @@ p


let handshake_msg_builder p info_hash = 
let res_buffer = Bytes.create 68 in
let open Stdlib.Bytes in 
(* pstrlen *)
let () = set_uint8 res_buffer 0 (19) in
(*pstr - protocol identifier*)
let protocol = of_string "BitTorrent protocol" in
let () = blit protocol 0 res_buffer 1 (length protocol) in
(*reserved bytes *)
let () = set_int32_be res_buffer 20 (Int32.of_int 0) in
let () = set_int32_be res_buffer 24 (Int32.of_int 0) in
(*info_hash *)
let () = blit info_hash 0 res_buffer 28 (length info_hash) in
(*peer_id *)
let peer_id = of_string p.id in
(* peer_id length exceeds 20 bytes, therefore we are ignoring the extra bytes*)
let () = blit peer_id 0 res_buffer 48 20 in
res_buffer

let handshake (p: [`Connected] t) info_hash = 
  let open Lwt_unix in
  let handshake_data = handshake_msg_builder p info_hash in
  let* _ = (
    match p.fd with 
    | None -> assert false
    | Some f -> send f handshake_data 0 (Stdlib.Bytes.length handshake_data) []
    ) in 
  let resp_buffer = Stdlib.Bytes.create 80 in
  let* _ = ( match p.fd with 
    | None -> assert false
    | Some f -> recv f resp_buffer 0 (80) []
    ) in 
  print_endline (Bytes.to_string resp_buffer);Lwt.return ()

