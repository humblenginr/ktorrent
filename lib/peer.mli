type 'a t constraint 'a = [< `Connected | `Unconnected]

val make: Ipaddr.V4.t -> int -> [`Unconnected] t
val sexp_of_t: [< `Unconnected | `Connected] t -> Core.Sexp.t
val ip: [< `Unconnected | `Connected] t -> Ipaddr.V4.t
val port: [< `Unconnected | `Connected] t -> int

val connect: [`Unconnected] t -> ([`Connected] t) option Lwt.t
val handshake: [`Connected] t -> bytes -> bytes -> unit Lwt.t

