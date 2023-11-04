
(* We assume that the client is handshaked here *)
let download_piece (peer: [`Connected] Peer.t  ) (piece_index: int) : unit Lwt.t = 
  (* 1. Check the connection status of the peer *)
  let can_request = Peer.can_receive peer in
  if can_request then
    let reqm = Peer.req
    else
  (* 2. If the state allows us to recieve, then we have to send request message, or else we have to wait till `unchoke` message from the peer*)
  (* 3. Send `request` message and recieve the piece from peer *)
