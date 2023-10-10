(* This module contains all the functions and types needed to interact with the Tracker and some helper functions*)

let is_udp url = String.starts_with ~prefix:"udp://" url

