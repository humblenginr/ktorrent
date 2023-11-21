
let (let*) = Lwt.bind

let block_size = 16000 

let protocol_string = "BitTorrent protocol"

(* Every connection the client makes with the peer has some state that has to be maintained *)

type peer = {
  ip: Ipaddr.V4.t;
  port: int; 

  (* The peer is choking us - the peer is not ready to send us any data*)
  mutable am_choking: int;
  mutable am_interested: int;
  (* we are choking the peer - we are not ready to send any data to the peer *)
  (* peer_choking: int; *)
  (* peer_interested: int; *)

  mutable fd: Lwt_unix.file_descr option;
  mutable bitfield: bytes option;
}

type 'a t = peer constraint 'a = [< `Connected | `Unconnected]

let make ip port : [`Unconnected] t = {
  ip
  ;port

  ;am_choking = 1
  ;  am_interested= 0
  (* ;peer_choking =1 *)
  (* ;peer_interested = 0 *)

  ;fd= None
  ; bitfield= None
}

let set_bitfield p bf = p.bitfield <- Some bf
let get_bitfield p = p.bitfield



let sexp_of_t t =
let open Core in
Sexp.List ([Sexp.Atom ( Ipaddr.V4.to_string t.ip); Sexp.Atom (Int.to_string t.port)])

let ip t = t.ip
let port t = t.port

(* When Lwt_unix.connect raises an exception, the promise returned by the `connect` function will be rejected with the exception it raised *)
let connect (p : [`Unconnected] t ) : ([`Connected] t) Lwt.t = 
  let* sck = Utils.create_tcp_socket () in
  let addr = Lwt_unix.ADDR_INET (Unix.inet_addr_of_string ( Ipaddr.V4.to_string p.ip), p.port) in
  let* _ = Lwt_unix.connect sck addr in
  p.fd <- Some sck;
  print_endline @@ "Connected to peer: " ^ Ipaddr.V4.to_string p.ip;
  Lwt.return @@ p
  

(* we basically have to wait for the `unchoke` message, only when we are being choked by the peer *)
let interested p = 
  let open Lwt_unix in
  let open Stdlib.Bytes in 
  let buffer = Message.to_bytes @@ Message.new_interested_msg () in
  let fd = Core.Option.value_exn p.fd in
  let* _ = send fd buffer 0 (length buffer) [] in
  p.am_interested <- 1;
  Lwt.return ()


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

let complete_handshake (p: [`Connected] t) torrent_file peer_id = 
  let open Lwt_unix in
  let open Stdlib.Bytes in 
  let info_hash = Bytes.of_string @@ Torrent.get_info_hash torrent_file in
  let buffer = make 68 ' ' in
  let handshake_data = handshake_msg_builder peer_id info_hash in
  let fd = Core.Option.value_exn p.fd in
  let* _ = send fd handshake_data 0 (length handshake_data) [] in
  let* _ = recv fd buffer 0 (length buffer) [] in
  (* let p = get_uint8 buffer 0 in *)
  if verify_handshake_response buffer then Lwt.return () else failwith "Could not complete handshake"

let receive_bitfield (p: [`Connected] t) tf =  
  let no_of_pieces = Torrent.no_of_pieces tf in
  (* How to handle the spare bits? *)
  let spare_bits = no_of_pieces mod 8 in
  let bitfield_bytes_len = (no_of_pieces / 8) + (if spare_bits = 0 then 0 else 1)  in
  let fd = Core.Option.value_exn p.fd in
  let* buffer = Utils.receive_from_socket fd (5 + bitfield_bytes_len) in
  print_endline @@ "bitfield buffer size: " ^ (Int.to_string @@ Stdlib.Bytes.length buffer);
  Lwt.return @@ Message.to_bytes @@ Message.new_bitfield_from_bytes buffer 

let receive_unchoke (p: [`Connected] t) =  
  let fd = Core.Option.value_exn p.fd in
  let* buffer = Utils.receive_from_socket fd (5) in
  let msg =  Message.to_bytes @@ Message.new_unchoke_from_bytes buffer in
  p.am_choking <- 0;
  Lwt.return msg

let receive_piece_block (p: [`Connected] t) =  
  let fd = Core.Option.value_exn p.fd in
  (* Piece message - 16000 block size, 9 -> id(1) type (4) offset(4), 4 - message_length*)
  let* buffer = Utils.receive_from_socket fd (16013) in
  (* just for verification that the message is piece message we are using this function *)
  Lwt.return @@ Message.get_piece_data @@ Message.new_piece_message_from_bytes buffer

let download_block p piece_index begin_offset = 
  let open Lwt_unix in 
  let open Stdlib.Bytes in
  let fd = Core.Option.value_exn p.fd in
  let request_msg = Message.new_request_msg piece_index begin_offset block_size |> Message.to_bytes in
  (*TOOD: Return value of send is the actual number of bytes sent. Therefore we need to make sure that the return value is equal to the length of the reqeuest message. *)
  let* _ = send fd request_msg 0 (length request_msg) [] in
  let* block = receive_piece_block p in
  print_endline @@ "downloaded block with index: " ^ (Int.to_string @@ begin_offset / 16000) ^ " of piece with index: " ^ (Int.to_string piece_index) ;
  Lwt.return (block)

