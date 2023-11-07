 type t =
    | Choke
    | Unchoke
    | Interested 
    | NotInterested
    | Have of int
    | Bitfield of bytes
    | Request of (int * int * int)
    | Piece of (int * int * bytes)
    | Cancel


    let new_interested_msg () = Interested
    let new_request_msg piece_index begin_off len = Request (piece_index, begin_off, len) 

    let get_message_id = function 
      | Choke -> 0
      | Unchoke -> 1
      | Interested -> 2
      | NotInterested -> 3
      | Have _ -> 4
      | Bitfield _ -> 5
      | Request _ -> 6
      | Piece _ -> 7
      | Cancel -> 8

    let calculate_length = function 
      | Choke -> 1
      | Unchoke -> 1
      | Interested -> 1
      | NotInterested -> 1
      | Have _ -> 5
      | Bitfield b -> 1 + Stdlib.Bytes.length b
      | Request _ -> 13
      | Piece (_, _, b) -> 9 + Stdlib.Bytes.length b
      | Cancel -> 13

    let message_bytes ?(payload_appender = fun buf -> buf) msg  = 
      let open Stdlib.Bytes in

      let len_and_id msg = (calculate_length msg, get_message_id msg) in

      let (len, id) = len_and_id msg in

      let buf_length = 4 + len in
      let buf = create buf_length in
      (*length*)
      let () = Stdint.Int32.to_bytes_big_endian (Stdint.Int32.of_int len) buf 0 in
      (*id*)
      let () = Stdint.Int8.to_bytes_big_endian (Stdint.Int8.of_int id) buf 4 in
      payload_appender buf

    let request_payload_appender buf piece_index begin_off len  = 
        let open Stdlib.Bytes in
        let b = create 12 in
        (*piece index*)
        let () = Stdint.Int32.to_bytes_big_endian (Stdint.Int32.of_int piece_index) b 0 in
        (*begin offset within the piece*)
        let () = Stdint.Int32.to_bytes_big_endian (Stdint.Int32.of_int begin_off) b 4 in
        (*requested lenght*)
        let () = Stdint.Int32.to_bytes_big_endian (Stdint.Int32.of_int len) b 8 in
        cat buf b
        
    let to_bytes = function 
      | Choke -> Stdlib.Bytes.create 5
      | Unchoke -> Stdlib.Bytes.create 5
      | Interested -> message_bytes (Interested) 
      | NotInterested -> Stdlib.Bytes.create 5
      | Have _ -> Stdlib.Bytes.create 5
      | Bitfield _ -> Stdlib.Bytes.create 5
      | Request d -> message_bytes (Request d)
      | Piece _ -> Stdlib.Bytes.create 5
      | Cancel -> Stdlib.Bytes.create 5

    let new_bitfield_from_bytes buf = 
      let length = Stdint.Int32.to_int @@ Stdint.Int32.of_bytes_big_endian buf 0 in
      let id = Stdint.Int8.to_int @@ Stdint.Int8.of_bytes_big_endian buf 4 in
      let bitfield_bytes_len = length - 1 in
      let bf = Bitfield Stdlib.Bytes.(sub buf 5 bitfield_bytes_len) in
      if id = get_message_id bf then bf else failwith "Given is not a bitfield message"
