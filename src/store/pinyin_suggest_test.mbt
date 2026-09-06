// Pinyin suggestion tests (pinyin-suggest task 2.1).

///|
fn pbase() -> @store.Store {
  @store.open(None, "2025-01-29").state
}

///|
fn input(st : @store.Store, q : String, at : Int64) -> Array[String] {
  let resp = @store.update(st, SearchInput(query=q, at=Some(at)))
  resp.state.suggestions.map(e => e.query)
}

///|
test "full pinyin prefix matches chinese history" {
  let st = @store.update(pbase(), SearchSubmit(query="春节", at=Some(1000L))).state
  assert_eq(input(st, "chun", 1000L), ["春节"])
  assert_eq(input(st, "chunjie", 1000L), ["春节"])
}

///|
test "initials prefix matches chinese history" {
  let st = @store.update(
      pbase(),
      SearchSubmit(query="中秋节", at=Some(1000L)),
    ).state
  assert_eq(input(st, "zqj", 1000L), ["中秋节"])
  assert_eq(input(st, "zhong", 1000L), ["中秋节"])
}

///|
test "raw text prefix outranks pinyin matches" {
  let st = @store.update(pbase(), SearchSubmit(query="春节", at=Some(1000L))).state
  let st = @store.update(st, SearchSubmit(query="chun城市", at=Some(2000L))).state
  // both match "chun": raw text prefix (tier 0) ranks first
  assert_eq(input(st, "chun", 3000L), ["chun城市", "春节"])
}

///|
test "chinese queries keep the original prefix path" {
  let st = @store.update(pbase(), SearchSubmit(query="春节", at=Some(1000L))).state
  let st = @store.update(
      st,
      SearchSubmit(query="春节联欢晚会", at=Some(1100L)),
    ).state
  assert_eq(input(st, "春节", 1200L).length(), 2)
  assert_eq(input(st, "端午", 1200L), [])
}

///|
test "ascii query with no pinyin match is empty" {
  let st = @store.update(pbase(), SearchSubmit(query="春节", at=Some(1000L))).state
  assert_eq(input(st, "xyz", 1000L), [])
}
