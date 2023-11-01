type 'a t constraint 'a = [< `Connected | `Unconnected]

val make: Ipaddr.V4.t -> int -> [`Unconnected] t
val sexp_of_t: [< `Unconnected | `Connected] t -> Core.Sexp.t
val ip: [< `Unconnected | `Connected] t -> Ipaddr.V4.t
val port: [< `Unconnected | `Connected] t -> int

(* connect peer attempts to establish a TCP connection with the peer. If successfull, it returns a connected peer, else it raises an exception *)
val connect: [`Unconnected] t -> ([`Connected] t) option Lwt.t
(* handshkae peer info_hash peer_id attempts to make a handshake and returns if it was successfully able to complete the handshake  *)
val handshake: [`Connected] t -> bytes -> bytes -> bool Lwt.t

