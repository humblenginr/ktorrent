open Core
open Xtorrent

let (let*) = Lwt.bind

let run () =
  let tr = Torrent.parse_file "tr1.torrent" in
  print_endline @@ Torrent.get_announce_url tr ;
  (*TODO: Refactor this to extract the host from announce url*)
  let* server_addr = Utils.get_inet_addr ("tracker.openbittorrent.com") 80 in 
  (* let* server_addr = Utils.get_inet_addr ("tracker.opentrackr.org") 1337 in  *)
  let* connect_id = Tracker.connect_to_tracker_udp server_addr in
  let info_hash = Bytes.of_string @@ Torrent.get_info_hash tr in
  let* peers = Tracker.get_peers_udp server_addr connect_id info_hash in
  print_endline @@ Sexp.to_string @@ List.sexp_of_t Peer.sexp_of_t peers;
  Lwt.return ()

  let _ = Lwt_main.run (run ())

