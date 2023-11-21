type 'a t constraint 'a = [< `Connected | `Unconnected]

val make: Ipaddr.V4.t -> int -> [`Unconnected] t
val sexp_of_t: [< `Unconnected | `Connected] t -> Core.Sexp.t
val ip: [< `Unconnected | `Connected] t -> Ipaddr.V4.t
val port: [< `Unconnected | `Connected] t -> int

val set_bitfield: [`Connected] t -> bytes -> unit
val get_bitfield: [`Connected] t -> bytes option

(* connect peer attempts to establish a TCP connection with the peer. If successfull, it returns a connected peer, else it raises an exception *)
val connect: [`Unconnected] t -> ([`Connected] t) Lwt.t
(* handshkae peer info_hash peer_id attempts to make a handshake and returns if it was successfully able to complete the handshake  *)

(* sends handshake and receives handshake response *)
val complete_handshake: [`Connected] t -> Torrent.t -> bytes -> unit Lwt.t

(* waits for the bitfield message from the peer *)
val receive_bitfield: [`Connected] t -> Torrent.t -> bytes Lwt.t


(* along with receiving the unchoke message, it also updates the state of the peer *)
val receive_unchoke: [`Connected] t  -> bytes Lwt.t

(* download block of a piece from a peer *)
(*
 download_block peer piece_index begin_offset - We can only request 16 KB of a piece at a time. The caller has to keep 
 track of the offset and call accordingly multiple times to get the full piece
 *)
val download_block: [`Connected] t  -> int -> int -> bytes Lwt.t

(* send interested message to the peer, and wait for it to send `unchoked` message *)
(* This should also update the state of the peer *)
val interested: [`Connected] t -> unit Lwt.t
(* 
   request a piece from the peer 
   request peer piece_index length
*)
(* val request: [`Connected] t -> int -> int -> int -> unit Lwt.t *)
(* send request message to the peer, and wait for the piece to be downloaded *)
(* val download_piece: [`Connected] t -> unit Lwt.t *)
(* can_receive checks the state of the connection and determines if we can request the peer for data.*)
(* can_receive = true means we are unchoked and we are interested in the peers pieces *)
(* val can_receive: [`Connected] t -> bool *)

(* 
   Think about this:
   Once the handshake is established, this module will automatically start listening to events from the peer and do the necessary things that has to be done
   For example, when there is an `Unchoke` message from the peer, then the connection state of the peer will be updated to reflect that

   Are we sure that the peer will send unchoke message only after 

*)

(*
  First make it work, then refactor it, and then optimise it
 *)
