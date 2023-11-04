(* Torrent module is responsible for dealing with everything related to the torrent files. It has getters for all the information we might need from 
   the torrent file
 *)

type t

(* Parses the torrent file at the given path*)
(* TODO: Change this to take errors into consideration*)
val parse_file: string -> t

(* Decode the torrent file and extract the announce_url from it *)
val get_announce_url: t -> string

(* Get the SHA1 hash string of `info`. Ideally, this will not be a part of this module. Have to be refactored later. *)
val get_info_hash: t -> string

(* Get the SHA1 hash of the piece at a given index *)
val get_piece_hash: t -> int -> string

(* Get the size of the torrent file to be downloaded*)
val size: t -> int

val pretty_print: t -> string
