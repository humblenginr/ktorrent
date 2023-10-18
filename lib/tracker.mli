(* 
   Tracker module should be responsible for dealing with everything related to the tracker server. 
   It includes functions to interact with the trackers.
   UDP related will go into a submodule in the future (similarly TCP as well).
 *)

type t

val make: int32 -> Unix.sockaddr -> t

(* connect_to_tracker_udp connects with the tracker server *)
val connect_to_tracker_udp: t -> unit Lwt.t

(* connect_to_tracker_udp sends an announce request to the udp tracker and gets the list of peers returned by the server *)
val get_peers_udp: t -> bytes -> (Peer.t list) Lwt.t

(* checks whether the tracker is connected *)
val is_connected: t -> bool

