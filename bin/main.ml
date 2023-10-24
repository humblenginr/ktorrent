open Core
open Xtorrent

let (let*) = Lwt.bind

let find_connectable_peer peer_id info_hash = List.map ~f:(
    fun peer -> 
      let* connected_peer = Peer.connect peer in
      Peer.handshake connected_peer peer_id info_hash 
)

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
  let* _ = Lwt.all @@ find_connectable_peer peer_id info_hash peers in

  (* let peer = Peer.make ( Ipaddr.V4.of_string_exn @@ "27.7.123.171") 10066 in *)
  (* let peer = Peer.make ( Ipaddr.V4.localhost) 5678 in *)
  (* let* peer = Peer.connect peer in *)
  (* let* _ = Peer.handshake peer peer_id info_hash in *)

  Lwt.return ()

  let _ = Lwt_main.run (run ())

