  type t
  val new_request_msg: int -> int -> int -> t
  val new_interested_msg: unit -> t
  val to_bytes: t -> bytes

  val new_bitfield_from_bytes: bytes -> t
  val new_unchoke_from_bytes: bytes -> t
  val new_piece_message_from_bytes: bytes ->t  

  val get_piece_data: t -> bytes

