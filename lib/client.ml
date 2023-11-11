open Core

let (let*) = Lwt.bind

type t = {
   torrent_file: Torrent.t
   ;mutable peers: [`Connected] Peer.t list
   ;mutable downloaded_data: bytes
}

let timeout = 5.


(* try to complete the handshake and receive bitfield *)
(* REFACTOR: This code structure has the same problem we had with javascript promises - the callback chain *)
let init_peer client peer tf peer_id =
   match%lwt (Utils.compute_promise_with_timeout (Peer.connect peer ) timeout) with
   | `Done connected_peer -> 
       begin 
        match%lwt (Utils.compute_promise_with_timeout (Peer.complete_handshake connected_peer tf peer_id) timeout) with
          | `Done _ -> 
             begin
              let* _ = Lwt_unix.sleep 3. in
              match%lwt Utils.compute_promise_with_timeout (Peer.receive_bitfield connected_peer tf) timeout with
              | `Done bitfield -> 
                  begin
                    Peer.set_bitfield connected_peer bitfield;
                    client.peers <- connected_peer :: client.peers;
                    print_endline @@ "Received bitfield: " ^ Stdlib.Bytes.to_string bitfield;
                    print_endline @@ "Initialised peer: " ^ Sexp.to_string @@ Peer.sexp_of_t @@ connected_peer;
                    (* After all this, I want to keep listening on all the messages being received on this file descriptor *)
                    Lwt.return @@ Some connected_peer
                  end
              | `Timeout -> failwith "Timed out waiting for bitfield message from the peer" 
             end
          | `Timeout -> failwith "Timed out waiting for handshake completion"
       end
    | `Timeout -> failwith "Timed out connecting to the peer"
     
let reset_data_buffer client = client.downloaded_data <- Stdlib.Bytes.make 1024 '0'
  
let init torrent_file peers peer_id  =
  let c = {
    peers = []
    ;torrent_file
    ;downloaded_data=Stdlib.Bytes.make 1024 '0'
} in
  let* p = List.map ~f:(fun peer -> 
    (*try syntax is used to make sure that the inability to initialize to a single peer does not reject the whole promise *)
    try%lwt init_peer c peer torrent_file peer_id with e -> print_endline @@ Exn.to_string e  ^ Sexp.to_string @@ Peer.sexp_of_t peer ; Lwt.return None
      ) peers |> Lwt.all in 
  let connected_peers = List.filter_map p ~f:(fun x -> x) in
  c.peers <- connected_peers; Lwt.return c

  (*
    !!!!!  STUDY ALGEBRAIC EFFECTS 
   *)

let download_piece_from_peer client peer piece_index =
  let piece_length = Torrent.get_piece_length client.torrent_file in
  let block_size = 16000 in

  let no_of_blocks = (piece_length / block_size) + (if (piece_length mod block_size) = 0 then 0 else 1) in

  let blocks_list = List.init no_of_blocks ~f:(fun x -> x+block_size) in
  let download = List.mapi blocks_list ~f:(fun _ offset -> Peer.request_block peer piece_index offset ) in
  Lwt.all download



(* We assume that the client is handshaked here *)
let start_download client = 
  let peer = match client.peers with 
  | [] -> failwith "Peers list is empty"
  | peer :: _ -> peer in

  let* _ = Peer.interested peer in
  print_endline "Sent interested message, now waiting for unchoke...";  
  let* _ = Peer.receive_unchoke peer in
  print_endline "Received unchoke message. Sending request message...";  

  let no_of_pieces = Torrent.no_of_pieces client.torrent_file in
  let pieces_list = List.init no_of_pieces ~f:(fun x -> x) in
  let piece_download = List.mapi pieces_list ~f:(fun i _ -> 
    let percent =  ((Int.to_float (i+1)) /. (Int.to_float no_of_pieces)) *. 100.0 in
    print_endline @@ "Downloading...  " ^ Float.to_string (percent) ^ "% completed.";
    download_piece_from_peer client peer i
  ) in
  let* _ = Lwt.all piece_download in
  Lwt.return () 
