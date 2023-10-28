open Core
open Xtorrent

let (let*) = Lwt.bind

let connect_with_timeout peer = Utils.compute_promise_with_timeout (Peer.connect peer) 3. 
let attempt_to_connect peers = List.map ~f:(connect_with_timeout) peers |> Lwt.all

let transaction_id = Option.value_exn @@ Int32.of_int 78834
let run () =
  let tr = Torrent.parse_file "tr4.torrent" in
  print_endline @@ Torrent.get_announce_url tr ;
  (*TODO: Refactor this to extract the host from announce url*)
  let* server_addr = Utils.get_inet_addr ("tracker.openbittorrent.com") 80 in 
  (* let* server_addr = Utils.get_inet_addr ("tracker.opentrackr.org") 1337 in  *)

  let peer_id = Utils.gen_peer_id () in
  let tracker = Tracker.make (transaction_id) server_addr in
  let* tracker = Tracker.connect_to_server_udp tracker in
  let* peers = Tracker.get_peers_udp tracker tr peer_id in
  print_endline @@ Sexp.to_string @@ List.sexp_of_t Peer.sexp_of_t peers;

  let info_hash = Bytes.of_string @@ Torrent.get_info_hash tr in
  (* print_endline "Finding connnectable peer...";  *)
  let* connection_result = attempt_to_connect peers in
  let connected_peers = List.filter_map connection_result ~f:(fun connection -> match connection with 
    | `Done x -> x
    | `Timeout -> None
  ) in
  let () = List.iter connected_peers ~f:(fun p -> print_endline ( Sexp.to_string @@ Peer.sexp_of_t p) ) in
  let* _ = Lwt.all @@ List.map connected_peers ~f:(fun p -> Peer.handshake p info_hash peer_id) in

  Lwt.return ()

  let _ = Lwt_main.run (run ())

