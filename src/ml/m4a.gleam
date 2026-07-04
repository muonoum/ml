import gleam/bit_array
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleam_community/ansi

pub fn read(data: BitArray) -> Result(Nil, String) {
  read_chunk(data, context: [])
}

// TODO: Samle opp i stedet for print
// TODO: Splitte opp, håndtere forskjellige datatyper
// TODO: Spesiell håndtering av '----': name=data

fn read_chunk(
  data: BitArray,
  context context: List(BitArray),
) -> Result(Nil, String) {
  case data {
    <<
      size:int-32,
      "data",
      _type_indicator:bytes-size(4),
      _locale:bytes-size(4),
      data:bytes-size(size - 16),
      rest:bits,
    >> -> {
      let kind = <<"data">>

      case context {
        [<<"trkn">>, <<"ilst">>, <<"meta">>, <<"udta">>, <<"moov">>] ->
          case data {
            <<_padding:bits-16, current:int-16, total:int-16, _padding:bits-16>> -> {
              let data = int.to_string(current) <> "/" <> int.to_string(total)
              print(kind:, data: <<data:utf8>>, context:)
              read_chunk(rest, context:)
            }

            _else -> Error("trkn/data")
          }

        [<<"disk">>, <<"ilst">>, <<"meta">>, <<"udta">>, <<"moov">>] ->
          case data {
            <<_padding:bits-16, current:int-16, total:int-16>> -> {
              let data = int.to_string(current) <> "/" <> int.to_string(total)
              print(kind:, data: <<data:utf8>>, context:)
              read_chunk(rest, context:)
            }

            _else -> Error("disk/data")
          }

        _else -> {
          print(kind:, data:, context:)
          let _ = read_chunk(data, context: [kind, ..context])
          read_chunk(rest, context:)
        }
      }
    }

    <<
      size:int-32,
      "mean",
      _version:bytes-1,
      _flags:bytes-3,
      data:bytes-size(size - 12),
      rest:bits,
    >> -> {
      let _ = read_chunk(data, context: [<<"mean">>, ..context])
      read_chunk(rest, context:)
    }

    <<
      size:int-32,
      "name",
      _version:bytes-1,
      _flags:bytes-3,
      data:bytes-size(size - 12),
      rest:bits,
    >> -> {
      print(kind: <<"name">>, data:, context:)
      let _ = read_chunk(data, context: [<<"name">>, ..context])
      read_chunk(rest, context:)
    }

    <<
      size:int-32,
      "meta",
      _padding:bytes-size(4),
      data:bytes-size(size - 12),
      rest:bits,
    >> -> {
      let _ = read_chunk(data, context: [<<"meta">>, ..context])
      read_chunk(rest, context:)
    }

    <<size:int-32, "----", data:bytes-size(size - 8), rest:bits>> -> {
      let _ = read_chunk(data, context: [<<"----">>, ..context])
      read_chunk(rest, context:)
    }

    <<size:int-32, 0xa9, kind:bytes-3, data:bytes-size(size - 8), rest:bits>> -> {
      let _ = read_chunk(data, context: [<<"_", kind:bits>>, ..context])
      read_chunk(rest, context:)
    }

    <<size:int-32, kind:bytes-4, data:bytes-size(size - 8), rest:bits>> -> {
      let _ = read_chunk(data, context: [kind, ..context])
      read_chunk(rest, context:)
    }

    _else -> Ok(Nil)
  }
}

fn format_bits(bits: BitArray) -> String {
  case bit_array.to_string(bits) {
    Ok(string) -> string
    Error(Nil) -> string.inspect(bits)
  }
}

fn format_value(bits: BitArray) -> String {
  let size = bit_array.byte_size(bits)

  case size < 50 {
    False -> "[..] " <> int.to_string(size) <> " bytes"
    True -> string.inspect(format_bits(bits))
  }
}

fn print(
  kind kind: BitArray,
  data data: BitArray,
  context context: List(BitArray),
) -> Nil {
  let context = case context {
    [] -> ""

    _else -> {
      let context =
        list.map(context, format_bits)
        |> list.reverse
        |> string.join("/")

      ansi.grey(context) <> " "
    }
  }

  io.println("")
  io.println(context)

  io.println(
    ansi.cyan(ansi.underline(format_bits(kind))) <> " " <> format_value(data),
  )
}
