// Trie unit tests (search-history task 1.1).

///|
test "insert then prefix match" {
  let t = @trie.Trie::new()
  t.insert("moonbit", "id-moonbit")
  t.insert("mooncake", "id-mooncake")
  t.insert("mongo", "id-mongo")
  t.insert("moon", "id-moon")
  // "mongo" diverges at "mon|g" — it must NOT match the "moon" prefix.
  let hits = t.prefix_query("moon")
  assert_eq(hits.length(), 3)
  assert_true(hits.contains("id-moonbit"))
  assert_true(hits.contains("id-mooncake"))
  assert_true(hits.contains("id-moon"))
  assert_false(hits.contains("id-mongo"))
  assert_eq(t.size, 4)
}

///|
test "prefix with no match returns empty" {
  let t = @trie.Trie::new()
  t.insert("moonbit", "a")
  assert_eq(t.prefix_query("bit"), [])
  assert_eq(t.prefix_query("moonbitt"), [])
}

///|
test "empty prefix matches everything" {
  let t = @trie.Trie::new()
  t.insert("a", "1")
  t.insert("bc", "2")
  assert_eq(t.prefix_query("").length(), 2)
}

///|
test "remove drops the entry from queries" {
  let t = @trie.Trie::new()
  t.insert("moonbit", "a")
  t.insert("mooncake", "b")
  assert_true(t.remove("moonbit", "a"))
  let hits = t.prefix_query("moon")
  assert_eq(hits, ["b"])
  // removing again finds nothing
  assert_false(t.remove("moonbit", "a"))
  assert_eq(t.size, 1)
}

///|
test "remove of absent key is a clean false" {
  let t = @trie.Trie::new()
  t.insert("x", "1")
  assert_false(t.remove("y", "1"))
  assert_false(t.remove("x", "other"))
  assert_eq(t.prefix_query("x"), ["1"])
}

///|
test "duplicate insert then two removes" {
  let t = @trie.Trie::new()
  t.insert("k", "a")
  t.insert("k", "a")
  assert_eq(t.prefix_query("k"), ["a", "a"])
  assert_true(t.remove("k", "a"))
  assert_eq(t.prefix_query("k"), ["a"])
  assert_true(t.remove("k", "a"))
  assert_eq(t.prefix_query("k"), [])
}

///|
test "single character boundaries" {
  let t = @trie.Trie::new()
  t.insert("m", "single")
  t.insert("mm", "double")
  assert_eq(t.prefix_query("m").length(), 2)
  assert_true(t.remove("m", "single"))
  assert_eq(t.prefix_query("m"), ["double"])
  assert_eq(t.prefix_query("mm"), ["double"])
}

///|
test "shared prefix survives targeted removal" {
  let t = @trie.Trie::new()
  t.insert("abc", "1")
  t.insert("abd", "2")
  assert_true(t.remove("abc", "1"))
  assert_eq(t.prefix_query("ab"), ["2"])
  assert_eq(t.prefix_query("a"), ["2"])
}
