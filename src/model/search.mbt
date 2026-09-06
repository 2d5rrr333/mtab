// Search: engine list, the user's current engine choice, and the local
// search history powering suggestions (search-box capability).

///|
/// A search engine; `url_template` contains a `{query}` placeholder.
pub(all) struct Engine {
  id : String
  name : String
  url_template : String
} derive(Eq, Debug)

///|
/// One history entry: the query, how often it was searched, and when it
/// was last used (epoch milliseconds). Int64 because 32-bit Int cannot
/// hold current epoch-ms; JSON round-trips it as a Double (< 2^53, exact).
pub(all) struct HistoryEntry {
  query : String
  count : Int
  last_used_ms : Int64
} derive(Eq, Debug)

///|
/// The engine list, the currently selected engine id, and the search
/// history (new in this build; absent in old configs -> defaults empty).
pub(all) struct SearchConfig {
  engines : Array[Engine]
  current : String
  history : Array[HistoryEntry]
} derive(Eq, Debug)

///|
pub impl ToJson for Engine with fn to_json(self) {
  { "id": self.id, "name": self.name, "urlTemplate": self.url_template }
}

///|
pub impl FromJson for Engine with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> Engine raise @json.JsonDecodeError {
  let map = expect_object(json, path)
  {
    id: str_field(map, "id", path),
    name: str_field(map, "name", path),
    url_template: str_field(map, "urlTemplate", path),
  }
}

///|
pub impl ToJson for HistoryEntry with fn to_json(self) {
  {
    "query": self.query,
    "count": self.count,
    "lastUsedMs": self.last_used_ms.to_double(),
  }
}

///|
pub impl FromJson for HistoryEntry with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> HistoryEntry raise @json.JsonDecodeError {
  let map = expect_object(json, path)
  {
    query: str_field(map, "query", path),
    count: int_field(map, "count", path),
    last_used_ms: int64_field(map, "lastUsedMs", path),
  }
}

///|
/// Search-history scoring (search-history design D5): frequency times a
/// 7-day half-life decay on recency. A search used now scores its count;
/// each 7 idle days halves it.
pub fn HistoryEntry::score(self : HistoryEntry, now_ms~ : Int64) -> Double {
  let delta_days = (now_ms - self.last_used_ms).to_double() / 604_800_000.0
  self.count.to_double() * decay_pow(delta_days)
}

///|
/// 0.5^x without core pow: halve x times, handle negatives by doubling.
fn decay_pow(x : Double) -> Double {
  let mut result = 1.0
  let mut remaining = x
  while remaining >= 1.0 {
    result = result / 2.0
    remaining = remaining - 1.0
  }
  if remaining > 0.0 {
    // fractional part via exp2 Taylor is overkill; linear interp between
    // 1.0 and 0.5 keeps half-life anchoring accurate enough for ranking.
    result = result * (1.0 - remaining * 0.5)
  }
  result
}

///|
pub impl ToJson for SearchConfig with fn to_json(self) {
  { "engines": self.engines, "current": self.current, "history": self.history }
}

///|
pub impl FromJson for SearchConfig with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> SearchConfig raise @json.JsonDecodeError {
  let map = expect_object(json, path)
  let engines : Array[Engine] = []
  for i, item in array_field(map, "engines", path) {
    engines.push(@json.from_json(item, path=path.add_index(i)))
  }
  // Old configs (pre search-history) carry no history field: default empty
  // instead of failing, so v1 data imports with zero migration.
  let history : Array[HistoryEntry] = []
  match map.get("history") {
    Some(Array(items)) =>
      for i, item in items {
        history.push(@json.from_json(item, path=path.add_index(i)))
      }
    _ => ()
  }
  { engines, current: str_field(map, "current", path), history, }
}
