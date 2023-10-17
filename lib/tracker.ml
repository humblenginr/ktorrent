(* This module contains all the functions and types needed to interact with the Tracker and some helper functions*)
(* open Ppx_let *)


let is_udp url = String.starts_with ~prefix:"udp://" url

let magic_number = "0000041727101980"
let action = "00000000"
let transaction_id = "000002FD"
let message = magic_number ^ action ^ transaction_id

(*1. Create a socket*)

