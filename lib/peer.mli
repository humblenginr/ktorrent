type 'a t constraint 'a = [< `Connected | `Unconnected]

val make: Ipaddr.V4.t -> int -> [`Unconnected] t
val sexp_of_t: [< `Unconnected | `Connected] t -> Core.Sexp.t
val ip: [< `Unconnected | `Connected] t -> Ipaddr.V4.t
val port: [< `Unconnected | `Connected] t -> int

(* connect peer attempts to establish a TCP connection with the peer. If successfull, it returns a connected peer, else it raises an exception *)
val connect: [`Unconnected] t -> ([`Connected] t) option Lwt.t
(* handshkae peer info_hash peer_id attempts to make a handshake and returns if it was successfully able to complete the handshake  *)
(* 
   Once the handshake is established, this module will automatically start listening to events from the peer and do the necessary things that has to be done
   For example, when there is an `Unchoke` message from the peer, then the connection state of the peer will be updated to reflect that
*)
val handshake: [`Connected] t -> bytes -> bytes -> bool Lwt.t
(* send interested message to the peer, and wait for it to send `unchoked` message *)
val interested: [`Connected] t -> unit Lwt.t
(* send request message to the peer, and wait for the piece to be downloaded *)
val download_piece: [`Connected] t -> unit Lwt.t
(* can_receive checks the state of the connection and determines if we can request the peer for data.*)
val can_receive: [`Connected] t -> bool

