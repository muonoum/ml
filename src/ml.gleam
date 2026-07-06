import argv
import gleam/bit_array
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import ml/id3
import ml/m4a
import ml/tag
import simplifile

pub fn main() -> Nil {
  let assert [path] = argv.load().arguments
  let assert Ok(data) = simplifile.read_bits(path)

  let tags = case data {
    <<"ID3", _rest:bits>> -> {
      let assert Ok(tags) = id3.read(data)
      tags
    }

    <<_size:bytes-4, "ftyp", "M4A", _rest:bits>> -> {
      let assert Ok(tags) = m4a.read(data)
      tags
    }

    _else -> panic as "file type"
  }

  use tag <- list.each(tags)

  case tag {
    tag.Bits(key:, value:) ->
      io.println(
        string.inspect(key) <> ": " <> string.inspect(truncate(value, 50)),
      )

    tag.Parts(key:, values:) -> {
      io.println(
        string.inspect(key)
        <> ": "
        <> string.inspect(list.map(values, truncate(_, 50))),
      )
    }
  }
}

fn truncate(data: BitArray, limit: Int) -> BitArray {
  case bit_array.byte_size(data) {
    size if size > limit ->
      bit_array.from_string("[..] (" <> int.to_string(size) <> " bytes)")

    _else -> data
  }
}
