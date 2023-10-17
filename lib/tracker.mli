(* 
   Tracker module should be responsible for dealing with everything related to the tracker server. 
   It includes functions to interact with the trackers.
   UDP related will go into a submodule in the future (similarly TCP as well).
 *)

module Peer : sig
  type t
  val make: string -> int -> t
  val sexp_of_t: t -> Core.Sexp.t
  val ip: t -> string
  val port: t -> int
end

(* connect_to_tracker_udp sends a connect request to the udp tracker and returns the `connect_id` returned by the server *)
val connect_to_tracker_udp: Unix.sockaddr -> int64 Lwt.t

(* connect_to_tracker_udp sends an announce request to the udp tracker and gets the list of peers returned by the server *)
val get_peers_udp: Unix.sockaddr -> int64 -> bytes -> (Peer.t list) Lwt.t

