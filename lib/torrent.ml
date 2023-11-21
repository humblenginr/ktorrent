open Core

type t = Bencode.t


let parse_file file = Bencode.decode (`File_path file)

let get_announce_url t = 
  let url_string = Option.value_exn (Bencode.dict_get t "announce") |> Bencode.as_string |> Option.value_exn in
  let uri = Uri.of_string url_string in
  match (Uri.host uri, Uri.port uri) with 
  | Some h, Some p -> Some (h, p) 
  | _ -> None

let pretty_print = Bencode.pretty_print

let get_info_hash t = 
let info = Option.value_exn (Bencode.dict_get t "info") in 
Sha1.string @@ Bencode.encode_to_string info |> Sha1.to_bin

let get_piece_length t = 
  let info = Option.value_exn (Bencode.dict_get t "info") in 
   Option.value_exn @@ Bencode.dict_get info "piece length" |> Bencode.as_int |> Option.value_exn |> Int64.to_int_exn

let get_file_name t = 
  let info = Option.value_exn (Bencode.dict_get t "info") in 
   Option.value_exn @@ Bencode.dict_get info "name" |> Bencode.as_string |> Option.value_exn

let size t = 
  let info = Option.value_exn (Bencode.dict_get t "info") in 
  match Bencode.dict_get info "files" with
  | None -> Option.value_exn (Bencode.dict_get info "length") |> Bencode.as_int |> Option.value_exn |> Int64.to_int |> Option.value_exn
  | Some (files) -> 
    let file_list = Option.value_exn (Bencode.as_list files) in 
    List.fold file_list ~init:0 ~f:(fun acc file  -> acc + ( Option.value_exn @@ Bencode.dict_get file "length" |> Bencode.as_int |> Option.value_exn |> Int64.to_int |> Option.value_exn ))
  
let no_of_pieces tf = size tf /  get_piece_length tf

  

