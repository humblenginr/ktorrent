type t

val make: string -> int -> t
val sexp_of_t: t -> Core.Sexp.t
val ip: t -> string
val port: t -> int

