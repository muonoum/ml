import gleam/dict.{type Dict}
import gleam/option.{type Option}

pub fn read(data: BitArray) {
  read_toplevel(data, dict.new())
}

fn read_toplevel(
  data: BitArray,
  results: Dict(BitArray, BitArray),
) -> Result(Dict(BitArray, BitArray), String) {
  case data {
    <<size:int-32, "moov", payload:bytes-size(size - 8), _rest:bits>> ->
      read_moov_atom(payload, results)

    <<size:int-32, _kind:bytes-4, _payload:bytes-size(size - 8), rest:bits>> ->
      read_toplevel(rest, results)

    _else -> Ok(results)
  }
}

fn read_moov_atom(
  data: BitArray,
  results: Dict(BitArray, BitArray),
) -> Result(Dict(BitArray, BitArray), String) {
  case data {
    <<size:int-32, "udta", payload:bytes-size(size - 8), _rest:bits>> ->
      read_udta_atom(payload, results)

    <<size:int-32, _kind:bytes-4, _payload:bytes-size(size - 8), rest:bits>> ->
      read_moov_atom(rest, results)

    _else -> Ok(results)
  }
}

fn read_udta_atom(
  data: BitArray,
  results: Dict(BitArray, BitArray),
) -> Result(Dict(BitArray, BitArray), String) {
  case data {
    <<
      size:int-32,
      "meta",
      _padding:bytes-size(4),
      payload:bytes-size(size - 12),
      _rest:bits,
    >> -> read_meta_atom(payload, results)

    <<size:int-32, _kind:bytes-4, _payload:bytes-size(size - 8), rest:bits>> ->
      read_udta_atom(rest, results)

    _else -> Ok(results)
  }
}

fn read_meta_atom(
  data: BitArray,
  results: Dict(BitArray, BitArray),
) -> Result(Dict(BitArray, BitArray), String) {
  case data {
    <<size:int-32, "ilst", payload:bytes-size(size - 8), _rest:bits>> ->
      read_ilst_atom(payload, results)

    <<size:int-32, _kind:bytes-4, _payload:bytes-size(size - 8), rest:bits>> ->
      read_meta_atom(rest, results)

    _else -> Ok(results)
  }
}

fn read_ilst_atom(
  data: BitArray,
  results: Dict(BitArray, BitArray),
) -> Result(Dict(BitArray, BitArray), String) {
  case data {
    <<size:int-32, 0xa9, kind:bytes-3, payload:bytes-size(size - 8), rest:bits>> ->
      read_data_atom(payload)
      |> dict.insert(results, <<"_", kind:bits>>, _)
      |> read_ilst_atom(rest, _)

    <<size:int-32, "----", payload:bytes-size(size - 8), rest:bits>> -> {
      let #(key, value) = read_freeform_atom(payload, option.None, option.None)

      dict.insert(results, key, value)
      |> read_ilst_atom(rest, _)
    }

    <<size:int-32, _kind:bytes-4, _payload:bytes-size(size - 8), rest:bits>> ->
      read_ilst_atom(rest, results)

    _else -> Ok(results)
  }
}

fn read_data_atom(data: BitArray) -> BitArray {
  case data {
    <<
      size:int-32,
      "data",
      _type_indicator:bytes-size(4),
      _locale:bytes-size(4),
      payload:bytes-size(size - 16),
      _rest:bits,
    >> -> payload

    _else -> panic as "data"
  }
}

fn read_freeform_atom(
  data: BitArray,
  key: Option(BitArray),
  value: Option(BitArray),
) -> #(BitArray, BitArray) {
  case data {
    <<
      size:int-32,
      "mean",
      _version:bytes-1,
      _flags:bytes-3,
      _payload:bytes-size(size - 12),
      rest:bits,
    >> ->
      case key, value {
        option.Some(key), option.Some(value) -> #(key, value)
        _key, _value -> read_freeform_atom(rest, key, value)
      }

    <<
      size:int-32,
      "name",
      _version:bytes-1,
      _flags:bytes-3,
      payload:bytes-size(size - 12),
      rest:bits,
    >> ->
      case key, value {
        _key, option.Some(value) -> #(payload, value)

        _key, option.None ->
          read_freeform_atom(rest, option.Some(payload), value)
      }

    <<
      size:int-32,
      "data",
      _type_indicator:bytes-size(4),
      _locale:bytes-size(4),
      payload:bytes-size(size - 16),
      rest:bits,
    >> ->
      case key, value {
        option.Some(key), _value -> #(key, payload)

        option.None, _value ->
          read_freeform_atom(rest, key, option.Some(payload))
      }

    _else -> panic as "freeform"
  }
}
