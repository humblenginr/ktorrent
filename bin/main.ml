open Core

let (let*) = Lwt.bind


(* Decode the torrent file and extract the announce_url from it *)
let get_announce_url file = 
let decoded_value = Bencode.decode (`File_path file) in
let announce_url = Option.value_exn (Bencode.dict_get decoded_value "announce") |> Bencode.as_string |> Option.value_exn in 
print_endline announce_url; announce_url

let get_info_hash file = 
let decoded_value = Bencode.decode (`File_path file) in
let info = Option.value_exn (Bencode.dict_get decoded_value "info") in  
Sha1.string @@ Bencode.encode_to_string info |> Sha1.to_bin


(* Creates a socket*)
let create_socket () = 
  let open Lwt_unix in
  Lwt.return @@ socket PF_INET SOCK_DGRAM 0

(* Gets the ip address of the url specified*)
let get_inet_addr _ port =
  let* addresses= Lwt_unix.getaddrinfo "tracker.openbittorrent.com" (Int.to_string port) [] in
  print_endline (Int.to_string @@ List.length addresses);
  Lwt.return @@ (List.hd_exn addresses).ai_addr

let draft_connect_request () = 
  let res_buffer = Bytes.create 16 in
  let open Stdlib.Bytes in 
  (*magic constant*)
  let () = set_int64_be res_buffer 0 (Int64.of_string "0x41727101980") in
  (*action number = 0 -> connect request*)
  let () = set_int32_be res_buffer 8 (Option.value_exn (Int32.of_int 0)) in
  (*transaction id *)
  let () = set_int32_be res_buffer 12 (Option.value_exn (Int32.of_int 34433)) in
  
  res_buffer

let draft_announce_request connect_id = 
  let open Stdlib.Bytes in  
  let res_buffer = create 98 in
  let () = set_int64_be res_buffer 0 (connect_id) in
  (*action number = 1 -> announce request*)
  let () = set_int32_be res_buffer 8 (Option.value_exn (Int32.of_int 1)) in
  (*transaction id *)
  let () = set_int32_be res_buffer 12 (Option.value_exn (Int32.of_int 87774)) in
  (*info hash*)
  let info_hash = Bytes.of_string @@ get_info_hash "tr1.torrent" in
  let () = blit info_hash 0 res_buffer 16 (length info_hash) in
  (* peer id *)
  let uuid = Uuid_unix.create () |> Uuid.to_string |> Bytes.of_string in
  let () = blit uuid 0 res_buffer 36 (length info_hash) in
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
let run_client () =
  let open Lwt in  
  let* sck = create_socket () in 
  let* server_address = get_inet_addr (get_announce_url "tr1.torrent") 80 in 
  (* let server_address = Core_unix.ADDR_INET (Core_unix.Inet_addr.localhost, 4445) in  *)
  print_endline ("Server address: " ^ Sexp.to_string (Core_unix.sexp_of_sockaddr server_address));
  let conn_req = draft_connect_request () in
  let open Lwt_unix in
  let* _ = (sendto sck conn_req 0 (Bytes.length conn_req) [] server_address) in
  print_endline ("Sent connect request to the server");

  let response_buffer = Bytes.create 1024 in
  let* _,_ = recvfrom sck response_buffer 0 1024 [] in
  let connect_id = Stdlib.Bytes.get_int64_be response_buffer 8 in
  print_endline ("Received message from server: " ^ (Int64.to_string connect_id));

  let announce_req = draft_announce_request (connect_id) in
  let* _ = (sendto sck announce_req 0 (Bytes.length announce_req) [] server_address) in
  print_endline ("Sent announce request to the server");

  let response_buffer = Bytes.create 1024 in
  let* _,_ = recvfrom sck response_buffer 0 1024 [] in
  print_endline "received response from the server"; 
  let seeders = Stdlib.Bytes.get_int32_be response_buffer 16 in
  print_endline ("Received message from server: " ^ (Int32.to_string seeders));
  return ()

  let _ = Lwt_main.run (run_client ())
  


  

