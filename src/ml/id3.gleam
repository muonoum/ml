import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/int
import gleam/result
import gleam/string

pub type Tag {
  Tag(frames: Dict(String, Frame))
}

pub type Frame {
  String(String)
  Bits(BitArray)
  Other
}

pub fn read(data: BitArray) -> Result(Tag, Nil) {
  case data {
    <<"ID3", 4:int, 0:int, flags:int-8, size:bytes-4, rest:bytes>> -> {
      assert int.bitwise_and(flags, 0b10000000) == 0 as "unsynchronisation"
      assert int.bitwise_and(flags, 0b01000000) == 0 as "extended header"
      let assert Ok(size) = read_synchsafe(size)

      case rest {
        <<frames:bytes-size(size), _rest:bytes>> -> {
          let assert Ok(frames) = read_frame(frames, dict.new())
          Ok(Tag(frames:))
        }

        _else -> panic as "frames"
      }
    }

    _else -> panic as "format"
  }
}

fn read_frame(
  data: BitArray,
  frames: Dict(String, Frame),
) -> Result(Dict(String, Frame), Nil) {
  case data {
    <<0, _rest:bits>> -> Ok(frames)

    <<key:bytes-4, size:bytes-4, _flags:bytes-2, rest:bits>> -> {
      use key <- result.try(bit_array.to_string(key))
      use size <- result.try(read_synchsafe(size))

      case rest {
        <<payload:bytes-size(size), rest:bits>> ->
          case key {
            "T" <> _ -> {
              use frame <- result.try(read_text_frame(payload))
              read_frame(rest, dict.insert(frames, key, frame))
            }

            "APIC" -> read_frame(rest, dict.insert(frames, key, Bits(payload)))
            _else -> read_frame(rest, dict.insert(frames, key, Other))
          }

        _else -> panic as "frame"
      }
    }

    _ -> panic as "frame"
  }
}

fn read_text_frame(payload: BitArray) -> Result(Frame, Nil) {
  case payload {
    // ISO-8859-1
    <<0:8, rest:bits>> ->
      bit_array.to_string(rest)
      // TODO
      |> result.map(string.drop_end(_, 1))
      |> result.map(String)

    // UTF-8
    <<3:8, rest:bits>> ->
      bit_array.to_string(rest)
      |> result.map(string.drop_end(_, 1))
      |> result.map(String)

    // <<1:8, 0xff, 0xfe, rest:bits>> -> echo #(key, "UTF-16 FFFE", rest)
    // <<1:8, 0xfe, 0xff, rest:bits>> -> echo #(key, "UTF-16 FEFF", rest)
    // <<2:8, rest:bits>> -> echo #(key, "UTF-16", rest)
    _else -> panic as "encoding"
  }
}

fn read_synchsafe(data: BitArray) -> Result(Int, Nil) {
  case data {
    <<a, b, c, d>> ->
      case <<0:4, a:int-7, b:int-7, c:int-7, d:int-7>> {
        <<size:int-32>> -> Ok(size)
        _else -> Error(Nil)
      }

    _else -> Error(Nil)
  }
}
