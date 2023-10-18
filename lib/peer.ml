
open Core

type t = (string * int)

let make ip port :t = (ip, port)

let sexp_of_t p =
let (ip, port) = p in
Sexp.List ([Sexp.Atom ip; Sexp.Atom (Int.to_string port)])

let ip (ip, _) = ip
let port (_, p) = p



(* let build_handshake_message info_hash peer_id =  *)
