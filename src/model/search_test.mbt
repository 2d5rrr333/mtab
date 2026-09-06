// Search-history model tests (search-history tasks 2.1 / 2.2).

///|
fn entry(query : String, count : Int, last_used_ms : Int64) -> HistoryEntry {
  { query, count, last_used_ms, }
}

///|
test "history absent in old config decodes to empty" {
  // v1 config from a pre-search-history build: no "history" key at all.
  let json : Json = {
    "engines": [
      {
        "id": "baidu",
        "name": "百度",
        "urlTemplate": "https://www.baidu.com/s?wd={query}",
      },
    ],
    "current": "baidu",
  }
  let decoded : SearchConfig = @json.from_json(json)
  assert_eq(decoded.history, [])
}

///|
test "history entries round-trip through JSON" {
  let e = entry("moonbit", 3, 1_757_000_000_000L)
  let json = ToJson::to_json(e).stringify()
  let decoded : HistoryEntry = @json.from_json(@json.parse(json))
  assert_eq(decoded, e)
}

///|
test "large epoch-ms round-trips exactly via Double" {
  let e = entry("q", 1, 1_757_123_456_789L)
  let json = ToJson::to_json(e).stringify()
  let decoded : HistoryEntry = @json.from_json(@json.parse(json))
  assert_eq(decoded.last_used_ms, 1_757_123_456_789L)
}

///|
test "full config with history round-trips" {
  let cfg = Config::default()
  let cfg = {
    ..cfg,
    search: {
      ..cfg.search,
      history: [entry("moonbit", 2, 1000L), entry("农历", 5, 2000L)],
    },
  }
  let decoded = Config::decode(cfg.encode())
  assert_eq(decoded, cfg)
}

///|
test "score: fresh search scores its count" {
  let e = entry("a", 4, 1000L)
  assert_eq(e.score(now_ms=1000L), 4.0)
}

///|
test "score: 7-day-old count-4 entry halves to 2" {
  let week_ms : Int64 = 604_800_000L
  let e = entry("a", 4, 1000L)
  let s = e.score(now_ms=1000L + week_ms)
  assert_true(s > 1.85 && s < 2.15)
}

///|
test "score: 14-day-old count-8 entry halves twice to 2" {
  let week_ms : Int64 = 604_800_000L
  let e = entry("a", 8, 1000L)
  let s = e.score(now_ms=1000L + week_ms * 2L)
  assert_true(s > 1.85 && s < 2.15)
}

///|
test "score: older never beats newer at equal count" {
  let week_ms : Int64 = 604_800_000L
  let old = entry("a", 3, 1000L)
  let new = entry("b", 3, 1000L + week_ms)
  let now = 1000L + week_ms * 2L
  assert_true(old.score(now_ms=now) < new.score(now_ms=now))
}
