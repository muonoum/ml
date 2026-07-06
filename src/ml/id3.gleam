import gleam/int
import gleam/result
import ml/tag.{type Tag}

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
          // TODO: <<"T",_>
          //       <<0:8,          _>> ISO-8859-1
          //       <<1:8,0xff,0xfe,_>> UTF-16
          //       <<1:8,0xfe,0xff,_>> UTF-16
          //       <<2:8,          _>> UTF-16
          //       <<3:8,          _>> UTF-8

          case key {
            <<"APIC">> ->
              [tag.Bits(key:, value: payload), ..tags]
              |> read_frame(rest, _)

            _else ->
              read_frame(rest, [
                tag.Parts(key:, values: tag.split_zero(payload)),
                ..tags
              ])
          }

        _else -> panic as "frame"
      }
    }

    _ -> panic as "frame"
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
