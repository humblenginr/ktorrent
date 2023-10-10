(* 1. Decode the torrent file and extract information from it *)
let decoded_value = Bencode.decode (`File_path "tr1.torrent") 
let announce_url = Option.get (Bencode.dict_get decoded_value "announce") |> Bencode.as_string |> Option.get
let () = print_string announce_url
