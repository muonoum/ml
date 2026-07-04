import gleam/dict.{type Dict}
import gleam/option.{type Option, None, Some}
import gleam/result

pub fn read(
  data: BitArray,
) -> Result(Dict(BitArray, BitArray), List(BitArray)) {
  read_toplevel(data, path: [], results: dict.new())
}

fn read_toplevel(
  data: BitArray,
  path path: List(BitArray),
  results results: Dict(BitArray, BitArray),
) -> Result(Dict(BitArray, BitArray), List(BitArray)) {
  case data {
    <<size:int-32, "moov", payload:bytes-size(size - 8), _rest:bits>> ->
      read_moov(payload, path: [<<"moov">>, ..path], results:)

    <<size:int-32, _kind:bytes-4, _payload:bytes-size(size - 8), rest:bits>> ->
      read_toplevel(rest, path:, results:)

    _else -> Ok(results)
  }
}

fn read_moov(
  data: BitArray,
  path path: List(BitArray),
  results results: Dict(BitArray, BitArray),
) -> Result(Dict(BitArray, BitArray), List(BitArray)) {
  case data {
    <<size:int-32, "udta", payload:bytes-size(size - 8), _rest:bits>> ->
      read_udta(payload, path: [<<"udta">>, ..path], results:)

    <<size:int-32, _kind:bytes-4, _payload:bytes-size(size - 8), rest:bits>> ->
      read_moov(rest, path:, results:)

    _else -> Ok(results)
  }
}

fn read_udta(
  data: BitArray,
  path path: List(BitArray),
  results results: Dict(BitArray, BitArray),
) -> Result(Dict(BitArray, BitArray), List(BitArray)) {
  case data {
    <<
      size:int-32,
      "meta",
      _padding:bytes-size(4),
      payload:bytes-size(size - 12),
      _rest:bits,
    >> -> read_meta(payload, path: [<<"meta">>, ..path], results:)

    <<size:int-32, _kind:bytes-4, _payload:bytes-size(size - 8), rest:bits>> ->
      read_udta(rest, path:, results:)

    _else -> Ok(results)
  }
}

fn read_meta(
  data: BitArray,
  path path: List(BitArray),
  results results: Dict(BitArray, BitArray),
) -> Result(Dict(BitArray, BitArray), List(BitArray)) {
  case data {
    <<size:int-32, "ilst", payload:bytes-size(size - 8), _rest:bits>> ->
      read_ilst(payload, path: [<<"ilst">>, ..path], results:)

    <<size:int-32, _kind:bytes-4, _payload:bytes-size(size - 8), rest:bits>> ->
      read_meta(rest, path:, results:)

    _else -> Ok(results)
  }
}

fn read_ilst(
  data: BitArray,
  path path: List(BitArray),
  results results: Dict(BitArray, BitArray),
) -> Result(Dict(BitArray, BitArray), List(BitArray)) {
  case data {
    <<size:int-32, "----", payload:bytes-size(size - 8), rest:bits>> -> {
      use #(key, value) <- result.try({
        let path = [<<"----">>, ..path]
        read_freeform(payload, path:, key: None, value: None)
      })

      let results = dict.insert(results, key, value)
      read_ilst(rest, path:, results:)
    }

    <<size:int-32, 0xa9, kind:bytes-3, payload:bytes-size(size - 8), rest:bits>> -> {
      use #(value, _rest) <- result.try(read_data(payload, path))
      let results = dict.insert(results, <<"_", kind:bits>>, value)
      read_ilst(rest, path:, results:)
    }

    <<size:int-32, kind:bytes-4, payload:bytes-size(size - 8), rest:bits>> -> {
      use #(value, _rest) <- result.try(read_data(payload, path))
      let results = dict.insert(results, <<kind:bits>>, value)
      read_ilst(rest, path:, results:)
    }

    _else -> Ok(results)
  }
}

fn read_freeform(
  data: BitArray,
  path path: List(BitArray),
  key key: Option(BitArray),
  value value: Option(BitArray),
) -> Result(#(BitArray, BitArray), List(BitArray)) {
  case data {
    <<
      size:int-32,
      "mean",
      _version:bytes-1,
      _flags:bytes-3,
      _payload:bytes-size(size - 12),
      rest:bits,
    >> -> read_freeform(rest, path:, key:, value:)

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
        None -> read_freeform(rest, path:, key: Some(payload), value:)
      }

    _else -> {
      use #(value, rest) <- result.try(read_data(data, path))

      case key {
        Some(key) -> Ok(#(key, value))
        None -> read_freeform(rest, path:, key:, value: Some(value))
      }
    }
  }
}

fn read_data(
  data: BitArray,
  path: List(BitArray),
) -> Result(#(BitArray, BitArray), List(BitArray)) {
  case data {
    <<
      size:int-32,
      "data",
      _type_indicator:bytes-size(4),
      _locale:bytes-size(4),
      payload:bytes-size(size - 16),
      rest:bits,
    >> -> Ok(#(payload, rest))

    _else -> Error([<<"data">>, ..path])
  }
}
