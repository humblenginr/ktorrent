
let (let*) = Lwt.bind

let protocol_string = "BitTorrent protocol"

(* Every connection the client makes with the peer has some state that has to be maintained *)

type peer = {
  ip: Ipaddr.V4.t;
  port: int; 

  (* The peer is choking us - the peer is not ready to send us any data*)
  (* am_choking: int; *)
  (* am_interested: int; *)
  (* we are choking the peer - we are not ready to send any data to the peer *)
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

module Message : sig
  type t
  val new_request_msg: int -> int -> int -> t
  val new_interested_msg: unit -> t
  val to_bytes: t -> bytes
  val new_bitfield_from_bytes: bytes -> t
end
=
struct
  type t =
    | Choke
    | Unchoke
    | Interested 
    | NotInterested
    | Have of int
    | Bitfield of bytes
    | Request of (int * int * int)
    | Piece of (int * int * bytes)
    | Cancel


    let new_interested_msg () = Interested
    let new_request_msg piece_index begin_off len = Request (piece_index, begin_off, len) 

    let get_message_id = function 
      | Choke -> 0
      | Unchoke -> 1
      | Interested -> 2
      | NotInterested -> 3
      | Have _ -> 4
      | Bitfield _ -> 5
      | Request _ -> 6
      | Piece _ -> 7
      | Cancel -> 8

    let calculate_length = function 
      | Choke -> 1
      | Unchoke -> 1
      | Interested -> 1
      | NotInterested -> 1
      | Have _ -> 5
      | Bitfield b -> 1 + Stdlib.Bytes.length b
      | Request _ -> 13
      | Piece (_, _, b) -> 9 + Stdlib.Bytes.length b
      | Cancel -> 13

    let message_bytes ?(payload_appender = fun buf -> buf) msg  = 
      let open Stdlib.Bytes in

      let len_and_id msg = (calculate_length msg, get_message_id msg) in

      let (len, id) = len_and_id msg in

      let buf_length = 4 + len in
      let buf = create buf_length in
      (*length*)
      let () = Stdint.Int32.to_bytes_big_endian (Stdint.Int32.of_int len) buf 0 in
      (*id*)
      let () = Stdint.Int8.to_bytes_big_endian (Stdint.Int8.of_int id) buf 4 in
      payload_appender buf

    let request_payload_appender buf piece_index begin_off len  = 
        let open Stdlib.Bytes in
        let b = create 12 in
        (*piece index*)
        let () = Stdint.Int32.to_bytes_big_endian (Stdint.Int32.of_int piece_index) b 0 in
        (*begin offset within the piece*)
        let () = Stdint.Int32.to_bytes_big_endian (Stdint.Int32.of_int begin_off) b 4 in
        (*requested lenght*)
        let () = Stdint.Int32.to_bytes_big_endian (Stdint.Int32.of_int len) b 8 in
        cat buf b
        
    let to_bytes = function 
      | Choke -> Stdlib.Bytes.create 5
      | Unchoke -> Stdlib.Bytes.create 5
      | Interested -> message_bytes (Interested) 
      | NotInterested -> Stdlib.Bytes.create 5
      | Have _ -> Stdlib.Bytes.create 5
      | Bitfield _ -> Stdlib.Bytes.create 5
      | Request d -> message_bytes (Request d)
      | Piece _ -> Stdlib.Bytes.create 5
      | Cancel -> Stdlib.Bytes.create 5

    let new_bitfield_from_bytes buf = 
      let length = Stdint.Int32.to_int @@ Stdint.Int32.of_bytes_big_endian buf 0 in
      let id = Stdint.Int8.to_int @@ Stdint.Int8.of_bytes_big_endian buf 4 in
      let bitfield_bytes_len = length - 1 in
      let bf = Bitfield Stdlib.Bytes.(sub buf 5 bitfield_bytes_len) in
      if id = get_message_id bf then bf else failwith "Given is not a bitfield message"
end

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
  let* _ = write fd buffer 0 (length buffer) in
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
  let* _ = write fd handshake_data 0 (length handshake_data) in
  let* _ = read fd buffer 0 (length buffer) in
  (* let p = get_uint8 buffer 0 in *)
  if verify_handshake_response buffer then Lwt.return () else failwith "Could not complete handshake"

let receive_bitfield (p: [`Connected] t) tf =  
  let open Lwt_unix in
  let open Stdlib.Bytes in 
  let no_of_pieces = Torrent.size tf /  Torrent.get_piece_length tf in
  (* How to handle the spare bits? *)
  let bitfield_bytes_len = no_of_pieces / 8 in
  let buffer = create (5 + bitfield_bytes_len) in
  let fd = Core.Option.value_exn p.fd in
  let* _ = read fd buffer 0 (length buffer) in





