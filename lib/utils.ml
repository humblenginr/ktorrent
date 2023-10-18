open Core

let (let*) = Lwt.bind

(* Creates a UDP socket*)
let create_socket () = 
  let open Lwt_unix in
  Lwt.return @@ socket PF_INET SOCK_DGRAM 0




(* Gets the ip address of the url specified*)
let get_inet_addr host port =
  let* addresses= Lwt_unix.getaddrinfo host (Int.to_string port) [] in
  (* let* addresses= Lwt_unix.getaddrinfo "tracker.openbittorrent.com" (Int.to_string port) [] in *)
  print_endline (Int.to_string @@ List.length addresses);
  Lwt.return @@ (List.hd_exn addresses).ai_addr


