import argv
import gleam/dict
import gleam/io
import ml/id3
import ml/m4a
import simplifile

pub fn main() -> Nil {
  let assert [path] = argv.load().arguments
  let assert Ok(data) = simplifile.read_bits(path)

  case data {
    <<"ID3", _rest:bits>> -> {
      let assert Ok(tag) = id3.read(data)

      dict.each(tag.frames, fn(key, frame) {
        let value = case frame {
          id3.String(text) -> text
          id3.Bits(_) -> ".."
          id3.Other -> "--"
        }

        io.println(key <> ": " <> value)
      })
    }

    <<_size:bytes-4, "ftyp", "M4A", _rest:bits>> -> {
      m4a.read(data)
      Nil
    }

    _else -> panic as "file type"
  }
}
