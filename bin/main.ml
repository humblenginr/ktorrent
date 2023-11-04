open Core
open Xtorrent

let (let*) = Lwt.bind

let print_peer peer = print_endline ( Sexp.to_string @@ Peer.sexp_of_t peer)

let print_peer_list l = 
  List.iter l ~f:(print_peer)

let connect_with_timeout peer = Utils.compute_promise_with_timeout (Peer.connect peer) 3. 
let attempt_to_connect peers = List.map ~f:(connect_with_timeout) peers |> Lwt.all

let handshake_with_timeout peer info_hash peer_id = Utils.compute_promise_with_timeout (Peer.handshake peer info_hash peer_id) 3.

let transaction_id = Option.value_exn @@ Int32.of_int 78834
let run () =
  let tr = Torrent.parse_file "tr2.torrent" in
  print_endline @@ Torrent.get_announce_url tr ;
  (*TODO: Refactor this to extract the host from announce url*)
  (* let* server_addr = Utils.get_inet_addr ("tracker.openbittorrent.com") 80 in  *)
  let* server_addr = Utils.get_inet_addr ("tracker.opentrackr.org") 1337 in 

  print_endline @@ Torrent.pretty_print tr;

  let peer_id = Utils.gen_peer_id () in
  let tracker = Tracker.make (transaction_id) server_addr in
  let* tracker = Tracker.connect_to_server_udp tracker in
  let* peers = Tracker.get_peers_udp tracker tr peer_id in
  print_endline @@ Sexp.to_string @@ List.sexp_of_t Peer.sexp_of_t peers;

  let info_hash = Bytes.of_string @@ Torrent.get_info_hash tr in
  let* connection_result = attempt_to_connect peers in
  let connected_peers = List.filter_map connection_result ~f:(fun connection -> match connection with 
    | `Done x -> x
    | `Timeout -> None
  ) in
  let () = List.iter connected_peers ~f:(fun p -> print_endline ( Sexp.to_string @@ Peer.sexp_of_t p) ) in

  let* res =  Lwt.all @@ List.map connected_peers ~f:(fun p -> 
    match%lwt handshake_with_timeout p info_hash peer_id with
    | `Done x -> print_endline ("Handshake: " ^  Bool.to_string x ^ " - Peer: " ^ (Sexp.to_string @@ Peer.sexp_of_t p));Lwt.return (p, x)
    | `Timeout -> print_endline ("Handshake: Request Timed out" ^ " - Peer: " ^ (Sexp.to_string @@ Peer.sexp_of_t p)); Lwt.return (p,false)
  ) in
  let handshaked_peers = List.filter_map ~f:(fun res -> match res  with 
      | (_, false) -> None
      | (p, true)  -> Some p) res in

  let () = print_peer_list handshaked_peers in
  (*Once we get the list of handshaked peers, we have to establish the *)

  Lwt.return ()
  let _ = Lwt_main.run (run ())

