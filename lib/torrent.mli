(* Torrent module should be responsible for dealing with everything related to the torrent files *)

type t

(* Parses the torrent file at the given path*)
(* TODO: Change this to take errors into consideration*)
val parse_file: string -> t

(* Decode the torrent file and extract the announce_url from it *)
val get_announce_url: t -> string

(* Get the SHA1 hash string of `info`. Ideally, this will not be a part of this module. Have to be refactored later. *)
val get_info_hash: t -> string
