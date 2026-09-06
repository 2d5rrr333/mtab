// Search-history store tests (search-history tasks 3.2 / 3.3 / 3.4).

///|
fn base() -> @store.Store {
  @store.open(None, "2025-01-29").state
}

///|
fn submit(st : @store.Store, q : String, at : Int64) -> @store.Store {
  @store.update(st, SearchSubmit(query=q, at=Some(at))).state
}

///|
test "search_input on empty query returns recent history" {
  let st = submit(base(), "older", 1000L)
  let st = submit(st, "newer", 2000L)
  let resp = @store.update(st, SearchInput(query="", at=Some(2000L)))
  let queries = resp.state.suggestions.map(e => e.query)
  assert_eq(queries, ["newer", "older"])
  assert_eq(resp.effects, [])
}

///|
test "search_input prefix filter is case-insensitive" {
  let st = submit(base(), "MoonBit", 1000L)
  let st = submit(st, "moonpie", 1100L)
  let st = submit(st, "zebra", 1200L)
  let resp = @store.update(st, SearchInput(query="MOON", at=Some(1200L)))
  let queries = resp.state.suggestions.map(e => e.query)
  // equal counts, moonpie used more recently -> ranks first (design D5)
  assert_eq(queries, ["moonpie", "MoonBit"])
}

///|
test "search_input with no match yields empty suggestions" {
  let st = submit(base(), "moonbit", 1000L)
  let resp = @store.update(st, SearchInput(query="xyz", at=Some(1000L)))
  assert_eq(resp.state.suggestions, [])
}

///|
test "submit records, bumps count and recency, no duplicate entries" {
  let st = submit(base(), "moonbit", 1000L)
  let st = submit(st, "moonbit", 5000L)
  let history = st.config.search.history
  assert_eq(history.length(), 1)
  assert_eq(history[0].count, 2)
  assert_eq(history[0].last_used_ms, 5000L)
}

///|
test "suggestions cap at 6; empty query orders by recency" {
  let mut st = base()
  // frequent "alpha" beats one-off newer entries ON SCORE, but an empty
  // query is pure recency (design D5): newest first.
  st = submit(st, "alpha", 1000L)
  st = submit(st, "alpha", 1001L)
  st = submit(st, "alpha", 1002L)
  st = submit(st, "beta", 2000L)
  st = submit(st, "gamma", 3000L)
  st = submit(st, "delta", 4000L)
  st = submit(st, "epsilon", 5000L)
  st = submit(st, "zeta", 6000L)
  let resp = @store.update(st, SearchInput(query="", at=Some(6000L)))
  assert_eq(resp.state.suggestions.length(), 6)
  assert_eq(resp.state.suggestions[0].query, "zeta")
  // typed prefix "a" is score-ranked: alpha (count 3) tops the list
  let typed = @store.update(st, SearchInput(query="a", at=Some(6000L)))
  assert_eq(typed.state.suggestions[0].query, "alpha")
}

///|
test "history capacity 100 evicts the lowest score" {
  let mut st = base()
  // fill 100 entries, all count=1, increasing recency
  for i in 0..<100 {
    st = submit(st, "q" + i.to_string(), i.to_int64() * 1000L)
  }
  assert_eq(st.config.search.history.length(), 100)
  // one more: the oldest (q0, count=1, t=0) must be evicted
  st = submit(st, "fresh", 1_000_000L)
  let history = st.config.search.history
  assert_eq(history.length(), 100)
  let has_q0 = history.any(e => e.query == "q0")
  assert_false(has_q0)
  let has_fresh = history.any(e => e.query == "fresh")
  assert_true(has_fresh)
}

///|
test "history_delete removes the entry and refreshes suggestions" {
  let st = submit(base(), "moonbit", 1000L)
  let st = submit(st, "other", 2000L)
  let resp = @store.update(st, HistoryDelete(query="moonbit"))
  let history = resp.state.config.search.history
  assert_false(history.any(e => e.query == "moonbit"))
  assert_true(history.any(e => e.query == "other"))
  let queries = resp.state.suggestions.map(e => e.query)
  assert_false(queries.contains("moonbit"))
  assert_eq(resp.effects, [Save])
}

///|
test "history_clear empties everything and saves" {
  let st = submit(base(), "moonbit", 1000L)
  let resp = @store.update(st, HistoryClear)
  assert_eq(resp.state.config.search.history, [])
  assert_eq(resp.state.suggestions, [])
  assert_eq(resp.effects, [Save])
}

///|
test "submit without at (old callers) still records with decay base 0" {
  let resp = @store.update(base(), SearchSubmit(query="legacy", at=None))
  let history = resp.state.config.search.history
  assert_eq(history.length(), 1)
  assert_eq(history[0].count, 1)
  assert_eq(history[0].last_used_ms, 0L)
}

///|
test "submit persists via save effect and refreshes suggestions" {
  let resp = @store.update(base(), SearchSubmit(query="moonbit", at=Some(9L)))
  assert_true(resp.effects is [OpenUrl(..)])
  // exactly one save comes from the history write path
  assert_eq(resp.state.suggestions.map(e => e.query), ["moonbit"])
  let resp2 = @store.update(resp.state, HistoryClear)
  assert_eq(resp2.effects, [Save])
}
