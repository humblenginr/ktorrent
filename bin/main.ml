open Core
open Xtorrent

let (let*) = Lwt.bind

let print_peer peer = print_endline ( Sexp.to_string @@ Peer.sexp_of_t peer)

let print_peer_list l = 
  List.iter l ~f:(print_peer)

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

  (*Once we get the list of handshaked peers, we have to establish the *)
  let client = Client.new_client () in
  let* _ =  Client.init_peers client peers tr peer_id in

  Lwt.return ()
  let _ = Lwt_main.run (run ())

