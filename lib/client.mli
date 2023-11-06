(* Client module will make use of the functions provided by Peer.ml, Tracker.ml and Torrent.ml to produce a BitTorrent client *)

type t

val init_peers: t -> [`Unconnected] Peer.t list -> bytes -> bytes -> unit list Lwt.t  
val new_client: unit -> t


