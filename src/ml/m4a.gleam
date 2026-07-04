import gleam/dict.{type Dict}
import gleam/option.{type Option, None, Some}
import gleam/result

pub fn read(data: BitArray) -> Result(Dict(BitArray, BitArray), String) {
  read_toplevel(data, dict.new())
}

fn read_toplevel(
  data: BitArray,
  results: Dict(BitArray, BitArray),
) -> Result(Dict(BitArray, BitArray), String) {
  case data {
    <<size:int-32, "moov", payload:bytes-size(size - 8), _rest:bits>> ->
      read_moov(payload, results)

    <<size:int-32, _kind:bytes-4, _payload:bytes-size(size - 8), rest:bits>> ->
      read_toplevel(rest, results)

    _else -> Ok(results)
  }
}

fn read_moov(
  data: BitArray,
  results: Dict(BitArray, BitArray),
) -> Result(Dict(BitArray, BitArray), String) {
  case data {
    <<size:int-32, "udta", payload:bytes-size(size - 8), _rest:bits>> ->
      read_udta(payload, results)

    <<size:int-32, _kind:bytes-4, _payload:bytes-size(size - 8), rest:bits>> ->
      read_moov(rest, results)

    _else -> Ok(results)
  }
}

fn read_udta(
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
    >> -> read_meta(payload, results)

    <<size:int-32, _kind:bytes-4, _payload:bytes-size(size - 8), rest:bits>> ->
      read_udta(rest, results)

    _else -> Ok(results)
  }
}

fn read_meta(
  data: BitArray,
  results: Dict(BitArray, BitArray),
) -> Result(Dict(BitArray, BitArray), String) {
  case data {
    <<size:int-32, "ilst", payload:bytes-size(size - 8), _rest:bits>> ->
      read_ilst(payload, results)

    <<size:int-32, _kind:bytes-4, _payload:bytes-size(size - 8), rest:bits>> ->
      read_meta(rest, results)

    _else -> Ok(results)
  }
}

fn read_ilst(
  data: BitArray,
  results: Dict(BitArray, BitArray),
) -> Result(Dict(BitArray, BitArray), String) {
  case data {
    <<size:int-32, "----", payload:bytes-size(size - 8), rest:bits>> -> {
      use #(key, value) <- result.try(read_freeform(payload, None, None))
      read_ilst(rest, dict.insert(results, key, value))
    }

    <<size:int-32, 0xa9, kind:bytes-3, payload:bytes-size(size - 8), rest:bits>> -> {
      use #(value, _rest) <- result.try(read_data(payload))
      read_ilst(rest, dict.insert(results, <<"_", kind:bits>>, value))
    }

    <<size:int-32, kind:bytes-4, payload:bytes-size(size - 8), rest:bits>> -> {
      use #(value, _rest) <- result.try(read_data(payload))
      read_ilst(rest, dict.insert(results, <<kind:bits>>, value))
    }

    _else -> Ok(results)
  }
}

fn read_freeform(
  data: BitArray,
  key: Option(BitArray),
  value: Option(BitArray),
) -> Result(#(BitArray, BitArray), String) {
  case data {
    <<
      size:int-32,
      "mean",
      _version:bytes-1,
      _flags:bytes-3,
      _payload:bytes-size(size - 12),
      rest:bits,
    >> -> read_freeform(rest, key, value)

    <<
      size:int-32,
      "name",
      _version:bytes-1,
      _flags:bytes-3,
      payload:bytes-size(size - 12),
      rest:bits,
    >> ->
      case value {
        Some(value) -> Ok(#(payload, value))
        None -> read_freeform(rest, Some(payload), value)
      }

    _else -> {
      use #(value, rest) <- result.try(read_data(data))

      case key {
        Some(key) -> Ok(#(key, value))
        None -> read_freeform(rest, key, Some(value))
      }
    }
  }
}

fn read_data(data: BitArray) -> Result(#(BitArray, BitArray), String) {
  case data {
    <<
      size:int-32,
      "data",
      _type_indicator:bytes-size(4),
      _locale:bytes-size(4),
      payload:bytes-size(size - 16),
      rest:bits,
    >> -> Ok(#(payload, rest))

    _else -> Error("data")
  }
}
