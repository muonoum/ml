import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import ml/tag.{type Tag}

@external(erlang, "ml_glue", "utf16_little_to_string")
fn utf16_little_to_string(data: BitArray) -> Result(String, Nil)

@external(erlang, "ml_glue", "utf16_big_to_string")
fn utf16_big_to_string(data: BitArray) -> Result(String, Nil)

@external(erlang, "ml_glue", "iso_8859_1_to_string")
fn iso_8859_1_to_string(data: BitArray) -> Result(String, Nil)

pub fn read(data: BitArray) -> Result(List(Tag), Nil) {
  case data {
    <<"ID3", 4:int, 0:int, flags:int-8, size:bytes-4, rest:bytes>> -> {
      assert int.bitwise_and(flags, 0b10000000) == 0 as "unsynchronisation"
      assert int.bitwise_and(flags, 0b01000000) == 0 as "extended header"
      let assert Ok(size) = read_synchsafe(size)

      case rest {
        <<frames:bytes-size(size), _rest:bytes>> -> read_frame(frames, [])
        _else -> panic as "frames"
      }
    }

    _else -> panic as "format"
  }
}

fn read_frame(data: BitArray, tags: List(Tag)) -> Result(List(Tag), Nil) {
  case data {
    <<0, _rest:bits>> -> Ok(tags)

    <<key:bytes-4, size:bytes-4, _flags:bytes-2, rest:bits>> -> {
      use size <- result.try(read_synchsafe(size))

      case rest {
        <<payload:bytes-size(size), rest:bits>> ->
          case key {
            <<"T", key:bytes-3>> -> {
              use values <- result.try({
                let #(decoder, data) = read_text_frame(payload)
                use part <- list.try_map(tag.split_zero(data))
                decoder(part)
              })

              let tag = tag.Strings(key: <<"T", key:bits>>, values:)
              read_frame(rest, [tag, ..tags])
            }

            <<"APIC">> -> {
              let tag = tag.Bits(key:, value: payload)
              read_frame(rest, [tag, ..tags])
            }

            _else -> {
              let tag = tag.Parts(key:, values: tag.split_zero(payload))
              read_frame(rest, [tag, ..tags])
            }
          }

        _else -> panic as "frame"
      }
    }

    _ -> panic as "frame"
  }
}

fn read_text_frame(
  data: BitArray,
) -> #(fn(BitArray) -> Result(String, Nil), BitArray) {
  case data {
    <<0:8, data:bits>> -> #(iso_8859_1_to_string, data)
    <<1:8, 0xff, 0xfe, data:bits>> -> #(utf16_little_to_string, data)
    <<1:8, 0xfe, 0xff, data:bits>> -> #(utf16_big_to_string, data)
    <<2:8, data:bits>> -> #(utf16_big_to_string, data)
    <<3:8, data:bits>> -> #(bit_array.to_string, data)
    _else -> panic
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
