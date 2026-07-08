import gleam/list

pub type Tag {
  Parts(key: BitArray, values: List(BitArray))
  Strings(key: BitArray, values: List(String))
  Bits(key: BitArray, value: BitArray)
}

pub fn split_zero(data: BitArray) -> List(BitArray) {
  split_zero_loop(data, 0, [])
}

fn split_zero_loop(
  data: BitArray,
  index: Int,
  results: List(BitArray),
) -> List(BitArray) {
  case data {
    <<>> -> list.reverse(results)
    <<0, rest:bytes>> -> split_zero_loop(rest, 0, results)

    <<v:bytes-size(index), 0, rest:bytes>> ->
      split_zero_loop(rest, 0, [v, ..results])

    <<v:bytes-size(index)>> -> list.reverse([v, ..results])
    _else -> split_zero_loop(data, index + 1, results)
  }
}
