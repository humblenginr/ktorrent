(* This module contains all the functions and types needed to interact with the Tracker and some helper functions*)
open Core

let (let*) = Lwt.bind

let magic_number = "0x41727101980"
let connect_action = Option.value_exn @@ Int32.of_int 0
let announce_action = Option.value_exn @@ Int32.of_int 1

type tracker = {
  transaction_id: int32;
  addr: Core_unix.sockaddr;
  mutable connect_id: int64;
}

type +'a t = tracker constraint 'a = [< `Connected | `Unconnected]

let make trans_id addr = ({
  transaction_id = trans_id;
  addr = addr;
  connect_id = Int64.zero;
})

let connect_request_data tr_id  = 
let res_buffer = Bytes.create 16 in
let open Stdlib.Bytes in 
(*magic constant*)
let () = set_int64_be res_buffer 0 (Int64.of_string magic_number) in
(*action number = 0 -> connect request*)
let () = set_int32_be res_buffer 8 (connect_action) in
(*transaction id *)
let () = set_int32_be res_buffer 12 (tr_id) in
res_buffer

(* TODO: Handle Errors*)
(* TODO: Add support for retries*)
let connect_to_server_udp t :[`Connected] t Lwt.t  = 
  let open Lwt in  

  let* sck = Utils.create_udp_socket () in 
  (* let server_address = Core_unix.ADDR_INET (Core_unix.Inet_addr.localhost, 4445) in  *)
  print_endline ("Server address: " ^ Sexp.to_string (Core_unix.sexp_of_sockaddr t.addr));
  let conn_req = connect_request_data t.transaction_id in
  let open Lwt_unix in
  let* _ = (sendto sck conn_req 0 (Bytes.length conn_req) [] t.addr) in
  print_endline ("Sent connect request to the server");

  let connect_response = Bytes.create 1024 in
  let* _,_ = recvfrom sck connect_response 0 1024 [] in
  let connect_id = Stdlib.Bytes.get_int64_be connect_response 8 in
  print_endline ("Received message from server: " ^ (Int64.to_string connect_id));
  t.connect_id <- connect_id;
  return t

let rec peers_from_response id byte_array acc off = 
  let open Stdlib.Bytes in
  if ((length byte_array) - off) < 6 then acc
  else 
  let ip = Ipaddr.V4.to_string @@ Ipaddr.V4.of_octets_exn ~off (to_string byte_array) in
  let port = Stdlib.Bytes.(get_uint16_be (byte_array) off+2) in
  let peer = Peer.make ip port id in
  if Ipaddr.V4.is_global (Ipaddr.V4.of_string_exn ip) then
  peers_from_response id byte_array (peer :: acc) (off + 6) 
  else
  peers_from_response id byte_array acc (off + 6) 

let announce_request_data info_hash connect_id uuid tr_id = 
  let open Stdlib.Bytes in  
  let res_buffer = create 98 in
  let () = set_int64_be res_buffer 0 (connect_id) in
  (*action number = 1 -> announce request*)
  let () = set_int32_be res_buffer 8 ( announce_action) in
  (*transaction id *)
  let () = set_int32_be res_buffer 12 (tr_id) in
  (*info hash*)
  print_endline ("info hash length: " ^ Int.to_string @@ length info_hash);
  let () = blit info_hash 0 res_buffer 16 (length info_hash) in
  (**)
  let () = blit uuid 0 res_buffer 36 (20) in
  (*downloaded*)
  let () = set_int64_be res_buffer 56 (Int64.of_int 0) in
  (*left*)
  let () = set_int64_be res_buffer 64 (Int64.of_int 0 ) in
  (*uploaded*)
  let () = set_int64_be res_buffer 72 (Int64.of_int 0 ) in
  (*event*)
  let () = set_int32_be res_buffer 80 (Option.value_exn (Int32.of_int 0)) in
  (*ip address*)
  let () = set_int32_be res_buffer 84 (Option.value_exn (Int32.of_int 0)) in
  (*num want*)
  let () = set_int32_be res_buffer 92 (Option.value_exn (Int32.of_int (-1))) in
  res_buffer

(* refer to http://www.bittorrent.org/beps/bep_0015.html for more information as to how to interact with udp trackers*)
(* TODO: Handle Errors*)
(* TODO: Add support for retries*)
let get_peers_udp (t : [`Connected] t) info_hash  = 
  let open Lwt_unix in

  let* sck = Utils.create_udp_socket () in 
  (* peer_id is a unique id for our client that will be stored in the  *)
  let peer_id = Bytes.of_string (Time_float.to_string_utc @@ Time_float.now ()) in
  let announce_req = announce_request_data info_hash t.connect_id peer_id t.transaction_id in
  let* _ = (sendto sck announce_req 0 (Bytes.length announce_req) [] t.addr) in
  print_endline ("Sent announce request to the server");

  let announce_response = Bytes.create 1024 in
  let* _,_ = recvfrom sck announce_response 0 1024 [] in
  print_endline "received response from the server"; 
  (* let transaction_id = List.rev @@ peers_from_response announce_response [] 20 in *)
  let peers = List.rev @@ peers_from_response (Bytes.to_string peer_id) announce_response [] 20 in
  Lwt.return peers
