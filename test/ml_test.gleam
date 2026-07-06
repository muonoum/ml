import ml/tag
import unitest

pub fn main() -> Nil {
  unitest.main()
}

pub fn empty_zero_test() {
  assert tag.split_zero(<<"":utf8>>) == []
  assert tag.split_zero(<<"":utf8, 0>>) == []
  assert tag.split_zero(<<"":utf8, 0, "":utf8>>) == []
  assert tag.split_zero(<<>>) == []
}

pub fn zero_test() {
  assert tag.split_zero(<<0, "a":utf8>>) == [<<"a":utf8>>]
  assert tag.split_zero(<<"a":utf8>>) == [<<"a":utf8>>]
  assert tag.split_zero(<<"a":utf8, "b":utf8>>) == [<<"a":utf8, "b":utf8>>]
  assert tag.split_zero(<<"a":utf8, "b":utf8, 0>>) == [<<"a":utf8, "b":utf8>>]
  assert tag.split_zero(<<"a":utf8, "b":utf8, 0, "c":utf8>>)
    == [<<"a":utf8, "b":utf8>>, <<"c":utf8>>]
  assert tag.split_zero(<<"a":utf8, 0, "b":utf8>>)
    == [<<"a":utf8>>, <<"b":utf8>>]
  assert tag.split_zero(<<"a":utf8, 0>>) == [<<"a":utf8>>]
}
