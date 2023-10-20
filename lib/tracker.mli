(* 
   Tracker module is responsible for dealing with everything related to the tracker server. 
   It includes functions to interact with the trackers.
   UDP related will go into a submodule in the future (similarly TCP as well).
 *)

(* Polymorphic variants are being used to improve the API surface. Although it is possible for the user to create a `Connected or `Unconnected type, 
   there is no constructor functions that gives `t` without the appropriate type paramater. So, this sort of enforces correct types being used as parameters.
 *)

(* The type of 'a is any type that has _utmost_ `Connected and `Unconnected  *)
type +'a t constraint 'a = [< `Connected | `Unconnected]

(* [`Unconnected] in the type definition means that the type parameter of the type `t` should be an instance of `Unconnected *)
val make: int32 -> Unix.sockaddr -> [`Unconnected] t

(* connect_to_tracker_udp connects with the tracker server *)
val connect_to_server_udp: [`Unconnected] t -> [`Connected] t Lwt.t

(* connect_to_tracker_udp sends an announce request to the udp tracker and gets the list of peers returned by the server *)
val get_peers_udp: [`Connected] t -> bytes -> (Peer.t list) Lwt.t

