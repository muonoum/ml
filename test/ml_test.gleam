import gleeunit
import gleeunit/should
import ml/id3

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn zero_test() {
  id3.read_zero(<<"a":utf8>>)
  |> should.equal(<<"a":utf8>>)

  id3.read_zero(<<"":utf8>>)
  |> should.equal(<<"":utf8>>)

  id3.read_zero(<<>>)
  |> should.equal(<<>>)

  id3.read_zero(<<"a":utf8, "b":utf8>>)
  |> should.equal(<<"a":utf8, "b":utf8>>)

  id3.read_zero(<<"a":utf8, "b":utf8, 0>>)
  |> should.equal(<<"a":utf8, "b":utf8>>)

  id3.read_zero(<<"a":utf8, "b":utf8, 0, "c":utf8>>)
  |> should.equal(<<"a":utf8, "b":utf8>>)

  id3.read_zero(<<"a":utf8, 0, "b":utf8>>)
  |> should.equal(<<"a":utf8>>)

  id3.read_zero(<<"a":utf8, 0>>)
  |> should.equal(<<"a":utf8>>)
}
