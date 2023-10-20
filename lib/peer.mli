type 'a t constraint 'a = [< `Connected | `Unconnected]

val make: string -> int -> string -> [`Unconnected] t
val sexp_of_t: [< `Unconnected | `Connected] t -> Core.Sexp.t
val ip: [< `Unconnected | `Connected] t -> string
val port: [< `Unconnected | `Connected] t -> int

val connect: [`Unconnected] t -> [`Connected] t Lwt.t
val handshake: [`Connected] t -> bytes -> unit Lwt.t

