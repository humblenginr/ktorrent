open Core

let (let*) = Lwt.bind

type t = {
  mutable bitfield: bytes option
  ; mutable peers: [`Connected] Peer.t list
}


(* try to complete the handshake and receive bitfield *)
(* REFACTOR: This code structure has the same problem we had with javascript promises - the callback chain *)
let init_peer client peer tf peer_id =
   match%lwt (Utils.compute_promise_with_timeout (Peer.connect peer ) 3.) with
   | `Done connected_peer -> 
       begin 
        match%lwt (Utils.compute_promise_with_timeout (Peer.complete_handshake connected_peer tf peer_id) 3.) with
          | `Done _ -> 
             begin
              match%lwt Utils.compute_promise_with_timeout (Peer.receive_bitfield connected_peer tf) 3. with
              | `Done bitfield -> 
                  begin
                    print_endline @@ "Received bitfield: " ^ Stdlib.Bytes.to_string bitfield;
                    client.bitfield <- Some bitfield;
                    client.peers <- connected_peer :: client.peers;
                    print_endline @@ "Initialised peer: " ^ Sexp.to_string @@ Peer.sexp_of_t @@ connected_peer;
                    Lwt.return ()
                  end
              | `Timeout -> failwith "Timed out waiting for bitfield message from the peer" 
             end
          | `Timeout -> failwith "Timed out waiting for handshake completion"
       end
    | `Timeout -> failwith "Timed out connecting to the peer"
     
  
let new_client () = { bitfield= None; peers = [] }

let init_peers client peers_list tf peer_id = 
  List.map ~f:(fun peer -> 
    (*try syntax is used to make sure that the inability to initialize to a single peer does not reject the whole promise *)
    try%lwt init_peer client peer tf peer_id with e -> print_endline @@ Exn.to_string e  ^ Sexp.to_string @@ Peer.sexp_of_t peer ; Lwt.return ()
    ) peers_list |> Lwt.all

(* We assume that the client is handshaked here *)
(* let rec download_piece (peer: [`Connected] Peer.t  ) (_: int) : unit Lwt.t =  *)
(*   (* here we have to send interested and wait for unchoke message *) *)
(*   match%lwt Utils.compute_promise_with_timeout (Peer.interested peer) 5. with  *)
(*   | `Done _ ->  *)
(*       begin *)
(*         (* let response_buffer = Stdlib.Bytes.create 1024 in *) *)
(*         (* let* resp = Peer.request peer piece_index 1024 1024 in *) *)
(*         Lwt.return () *)
(*       end *)
(*   | `Timeout -> failwith "Timed out waiting for unchoke message" *)
