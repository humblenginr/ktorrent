open Core

type t = Bencode.t


let parse_file file = Bencode.decode (`File_path file)

let get_announce_url t = 
Option.value_exn (Bencode.dict_get t "announce") |> Bencode.as_string |> Option.value_exn 

let get_info_hash t = 
let info = Option.value_exn (Bencode.dict_get t "info") in 
Sha1.string @@ Bencode.encode_to_string info |> Sha1.to_bin

let size t = 
  let info = Option.value_exn (Bencode.dict_get t "info") in 
  match Bencode.dict_get info "files" with
  | None -> Option.value_exn (Bencode.dict_get info "length") |> Bencode.as_int |> Option.value_exn |> Int64.to_int |> Option.value_exn
  | Some (files) -> 
    let file_list = Option.value_exn (Bencode.as_list files) in 
    List.fold file_list ~init:0 ~f:(fun acc file  -> acc + ( Option.value_exn @@ Bencode.dict_get file "length" |> Bencode.as_int |> Option.value_exn |> Int64.to_int |> Option.value_exn ))
  

  

