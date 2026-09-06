// URL normalization tests (task 2.2, bookmark-grid spec).

///|
test "scheme is completed with https" {
  assert_eq(normalize_url("example.com"), Some("https://example.com"))
  assert_eq(
    normalize_url("moonbitlang.com/docs"),
    Some("https://moonbitlang.com/docs"),
  )
}

///|
test "existing http scheme is preserved" {
  assert_eq(normalize_url("http://a.b/c"), Some("http://a.b/c"))
  assert_eq(normalize_url("https://a.b/c?q=1"), Some("https://a.b/c?q=1"))
}

///|
test "empty input is rejected" {
  assert_true(normalize_url("") is None)
  assert_true(normalize_url("   ") is None)
}

///|
test "invalid input is rejected" {
  // no host
  assert_true(normalize_url("https://") is None)
  // whitespace in host
  assert_true(normalize_url("not a url") is None)
  // host without a dot
  assert_true(normalize_url("example") is None)
}

///|
test "localhost is accepted" {
  assert_eq(
    normalize_url("localhost:3000/app"),
    Some("https://localhost:3000/app"),
  )
}
