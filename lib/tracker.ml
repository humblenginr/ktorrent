(* This module contains all the functions and types needed to interact with the Tracker and some helper functions*)
open Core

let (let*) = Lwt.bind

module Peer = struct
  open Core

  type t = (string * int)

  let make ip port :t = (ip, port)

  let sexp_of_t p =
  let (ip, port) = p in
  Sexp.List ([Sexp.Atom ip; Sexp.Atom (Int.to_string port)])

  let ip (ip, _) = ip
  let port (_, p) = p
end;;
  

let magic_number = "0x41727101980"
let connect_action = 0
let announce_action = 1
let transaction_id = 455334



let connect_to_tracker_udp server_addr = 
  let open Lwt in  

  let connect_request_data () = 
  let res_buffer = Bytes.create 16 in
  let open Stdlib.Bytes in 
  (*magic constant*)
  let () = set_int64_be res_buffer 0 (Int64.of_string magic_number) in
  (*action number = 0 -> connect request*)
  let () = set_int32_be res_buffer 8 (Option.value_exn (Int32.of_int connect_action)) in
  (*transaction id *)
  let () = set_int32_be res_buffer 12 (Option.value_exn (Int32.of_int transaction_id)) in
  res_buffer in

  let* sck = Utils.create_socket () in 
  (* let server_address = Core_unix.ADDR_INET (Core_unix.Inet_addr.localhost, 4445) in  *)
  print_endline ("Server address: " ^ Sexp.to_string (Core_unix.sexp_of_sockaddr server_addr));
  let conn_req = connect_request_data () in
  let open Lwt_unix in
  let* _ = (sendto sck conn_req 0 (Bytes.length conn_req) [] server_addr) in
  print_endline ("Sent connect request to the server");

  let connect_response = Bytes.create 1024 in
  let* _,_ = recvfrom sck connect_response 0 1024 [] in
  let connect_id = Stdlib.Bytes.get_int64_be connect_response 8 in
  print_endline ("Received message from server: " ^ (Int64.to_string connect_id));
  return connect_id


(* refer to http://www.bittorrent.org/beps/bep_0015.html for more information as to how to interact with udp trackers*)
let get_peers_udp server_addr connect_id info_hash  = 
  let open Lwt_unix in

  let rec helper byte_array acc off = 
  let open Stdlib.Bytes in
  if ((length byte_array) - off) < 6 then acc
  else 
  let ip = Ipaddr.V4.to_string @@ Ipaddr.V4.of_octets_exn ~off (to_string byte_array) in
  let port = Stdlib.Bytes.(get_uint16_be (byte_array) off+2) in
  let peer = Peer.make ip port in
  helper byte_array (peer :: acc) (off + 6) in

  let announce_request_data () = 
  let open Stdlib.Bytes in  
  let res_buffer = create 98 in
  let () = set_int64_be res_buffer 0 (connect_id) in
  (*action number = 1 -> announce request*)
  let () = set_int32_be res_buffer 8 (Option.value_exn (Int32.of_int announce_action)) in
  (*transaction id *)
  let () = set_int32_be res_buffer 12 (Option.value_exn (Int32.of_int transaction_id)) in
  (*info hash*)
  let () = blit info_hash 0 res_buffer 16 (length info_hash) in
  (* peer id. TODO: make it such that this is unique*)
  let uuid = Bytes.of_string (Time_float.to_string_utc @@ Time_float.now ()) in
  let () = blit uuid 0 res_buffer 36 (length uuid) in
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
  res_buffer in


  let* sck = Utils.create_socket () in 
  let announce_req = announce_request_data () in
  let* _ = (sendto sck announce_req 0 (Bytes.length announce_req) [] server_addr) in
  print_endline ("Sent announce request to the server");
  let announce_response = Bytes.create 1024 in
  let* _,_ = recvfrom sck announce_response 0 1024 [] in
  print_endline "received response from the server"; 
  let peers = List.rev @@ helper announce_response [] 20 in
  Lwt.return peers
