(* Client module will make use of the functions provided by Peer.ml, Tracker.ml and Torrent.ml to produce a BitTorrent client *)

type t

val init: Torrent.t -> [`Unconnected] Peer.t list -> bytes -> t Lwt.t  
val start_download: t -> unit Lwt.t


