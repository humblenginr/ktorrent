open Core

type t = Bencode.t

let parse_file file = Bencode.decode (`File_path file)

let get_announce_url t = 
Option.value_exn (Bencode.dict_get t "announce") |> Bencode.as_string |> Option.value_exn 

let get_info_hash t = 
let info = Option.value_exn (Bencode.dict_get t "info") in 
Sha1.string @@ Bencode.encode_to_string info |> Sha1.to_bin

