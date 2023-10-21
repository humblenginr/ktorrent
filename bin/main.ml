open Core
open Xtorrent

let (let*) = Lwt.bind

let transaction_id = Option.value_exn @@ Int32.of_int 89983
let run () =
  let tr = Torrent.parse_file "tr1.torrent" in
  print_endline @@ Torrent.get_announce_url tr ;
  (*TODO: Refactor this to extract the host from announce url*)
  let* server_addr = Utils.get_inet_addr ("tracker.openbittorrent.com") 80 in 
  (* let* server_addr = Utils.get_inet_addr ("tracker.opentrackr.org") 1337 in  *)
  let tracker = Tracker.make (transaction_id) server_addr in
  let* tracker = Tracker.connect_to_server_udp tracker in
  let info_hash = Bytes.of_string @@ Torrent.get_info_hash tr in
  let* peers = Tracker.get_peers_udp tracker info_hash in
  print_endline @@ Sexp.to_string @@ List.sexp_of_t Peer.sexp_of_t peers;

  (*for testing*)
  let peer_id = (Time_float.to_string_utc @@ Time_float.now ()) in
  (* let peer = Peer.make "127.0.0.1" 5678 peer_id in *)
  let peer = Peer.make (Ipaddr.V4.of_string_exn "171.76.47.5") 43856 peer_id in
  print_endline "Connecting to peer"; 
  let* connected_peer = Peer.connect peer in
  print_endline "Establishing handshake"; 
  let* () = Peer.handshake connected_peer info_hash in

  Lwt.return ()

  let _ = Lwt_main.run (run ())

