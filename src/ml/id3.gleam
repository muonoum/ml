import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import ml/tag.{type Tag}

@external(erlang, "ml_glue", "iso_8859_1_to_string")
fn iso_8859_1_to_string(data: BitArray) -> Result(String, Nil)

pub fn read(data: BitArray) -> Result(List(Tag), Nil) {
  case data {
    <<"ID3", 4:int, 0:int, flags:int-8, size:bytes-4, rest:bytes>> -> {
      assert int.bitwise_and(flags, 0b10000000) == 0 as "unsynchronisation"
      assert int.bitwise_and(flags, 0b01000000) == 0 as "extended header"
      let assert Ok(size) = read_synchsafe(size)

      case rest {
        <<frames:bytes-size(size), _rest:bytes>> -> read_frames(frames, [])
        _else -> Error(Nil)
      }
    }

    _else -> Error(Nil)
  }
}

fn read_frames(data: BitArray, tags: List(Tag)) -> Result(List(Tag), Nil) {
  case data {
    <<0, _rest:bits>> -> Ok(tags)

    <<key:bytes-4, size:bytes-4, _flags:bytes-2, data:bits>> -> {
      use size <- result.try(read_synchsafe(size))

      case data {
        <<data:bytes-size(size), rest:bits>> -> {
          use tag <- result.try(read_frame(key, data))
          read_frames(rest, [tag, ..tags])
        }

        _else -> Error(Nil)
      }
    }

    _else -> Error(Nil)
  }
}

fn read_frame(key: BitArray, data: BitArray) -> Result(Tag, Nil) {
  case key {
    <<"T", key:bytes-3>> -> {
      use values <- result.try(read_text_frame(data))
      Ok(tag.Strings(key: <<"T", key:bits>>, values:))
    }

    <<"APIC">> -> Ok(tag.Bits(key:, value: data))
    _else -> Ok(tag.Parts(key:, values: tag.split_zero(data)))
  }
}

fn read_text_frame(data: BitArray) -> Result(List(String), Nil) {
  case data {
    <<0:8, data:bits>> ->
      list.try_map(tag.split_zero(data), iso_8859_1_to_string)

    <<1:8, 0xff, 0xfe, _data:bits>>
    | <<1:8, 0xfe, 0xff, _data:bits>>
    | <<2:8, _data:bits>> -> panic as "utf-16"

    <<3:8, data:bits>> ->
      list.try_map(tag.split_zero(data), bit_array.to_string)

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
