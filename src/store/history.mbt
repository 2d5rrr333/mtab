// Search-history recording and suggestion retrieval (search-history
// design D4/D5): trie prefix matching plus frequency x half-life scoring,
// capacity-bounded at HISTORY_LIMIT entries.

///|
/// Maximum stored history entries (search-box spec: 100).
pub const HISTORY_LIMIT : Int = 100

///|
/// Maximum suggestions shown at once (search-box spec: 6).
pub const SUGGESTION_LIMIT : Int = 6

///|
/// Record one submitted search: bump count + recency of an existing entry,
/// or append a fresh one; evict the lowest-scoring entry when over limit.
/// Ties on score evict the oldest last_used_ms (deterministic).
fn record_search(
  history : Array[@model.HistoryEntry],
  query : String,
  now_ms : Int64,
) -> Array[@model.HistoryEntry] {
  let next = history.copy()
  let mut updated = false
  for i, e in next {
    if e.query == query {
      next[i] = { ..e, count: e.count + 1, last_used_ms: now_ms, }
      updated = true
      break
    }
  }
  if !updated {
    next.push({ query, count: 1, last_used_ms: now_ms, })
  }
  if next.length() > HISTORY_LIMIT {
    evict_lowest(next, now_ms)
  }
  next
}

///|
/// Remove one entry, choosing the minimum score; ties go to the entry with
/// the oldest last_used_ms; remaining ties break on lexicographic query so
/// the choice is fully deterministic.
fn evict_lowest(entries : Array[@model.HistoryEntry], now_ms : Int64) -> Unit {
  let mut victim = 0
  for i, e in entries {
    if i == 0 {
      continue
    }
    let cur = entries[victim]
    let es = e.score(now_ms~)
    let cs = cur.score(now_ms~)
    if es < cs ||
      (es == cs && e.last_used_ms < cur.last_used_ms) ||
      (es == cs && e.last_used_ms == cur.last_used_ms && e.query < cur.query) {
      victim = i
    }
  }
  ignore(entries.remove(victim))
}

///|
/// Suggestions for an input: empty query -> most recent entries by
/// last_used_ms; a pure-ASCII-letter query goes through the three-tier
/// pinyin path (pinyin-suggest D2); anything else uses the trie prefix
/// match. Never persists.
fn suggest_for(
  history : Array[@model.HistoryEntry],
  query : String,
  now_ms : Int64,
) -> Array[@model.HistoryEntry] {
  let trimmed = query.trim().to_owned()
  if trimmed == "" {
    return recent_suggestions(history)
  }
  let lower = trimmed.to_lower()
  if is_ascii_letters(lower) {
    return suggest_ascii(history, lower, now_ms)
  }
  // Build a trie over lowercased queries, id = query text itself.
  let trie = @trie.Trie::new()
  for e in history {
    trie.insert(e.query.to_lower(), e.query)
  }
  let ids = trie.prefix_query(lower)
  let matched : Array[@model.HistoryEntry] = []
  for id in ids {
    for e in history {
      if e.query == id {
        matched.push(e)
        break
      }
    }
  }
  sort_by_score(matched, now_ms)
  first_n(matched, SUGGESTION_LIMIT)
}

///|
/// Whether `s` is non-empty and consists only of a-z.
fn is_ascii_letters(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }
  for _, c in s {
    if c < 'a' || c > 'z' {
      return false
    }
  }
  true
}

///|
/// Three-tier match for ASCII-letter queries (pinyin-suggest D2):
/// tier 0 raw text prefix, tier 1 full-pinyin prefix, tier 2 initials
/// prefix. Tier ranks above score; ties fall back to the score order.
fn suggest_ascii(
  history : Array[@model.HistoryEntry],
  q : String,
  now_ms : Int64,
) -> Array[@model.HistoryEntry] {
  // (tier, entry) pairs
  let matched : Array[(Int, @model.HistoryEntry)] = []
  for e in history {
    let lq = e.query.to_lower()
    let tier = if lq.has_prefix(q) {
      0
    } else if @pinyin.phrase_pinyin(e.query).to_lower().has_prefix(q) {
      1
    } else if @pinyin.phrase_initials(e.query).to_lower().has_prefix(q) {
      2
    } else {
      -1
    }
    if tier >= 0 {
      matched.push((tier, e))
    }
  }
  // insertion sort: tier asc, then the established entry order
  for i in 1..<matched.length() {
    let mut j = i
    while j > 0 && pair_before(matched[j], matched[j - 1], now_ms) {
      let tmp = matched[j - 1]
      matched[j - 1] = matched[j]
      matched[j] = tmp
      j = j - 1
    }
  }
  let out : Array[@model.HistoryEntry] = []
  for pair in matched {
    if out.length() == SUGGESTION_LIMIT {
      break
    }
    out.push(pair.1)
  }
  out
}

///|
fn pair_before(
  a : (Int, @model.HistoryEntry),
  b : (Int, @model.HistoryEntry),
  now_ms : Int64,
) -> Bool {
  if a.0 != b.0 {
    return a.0 < b.0
  }
  entry_before(a.1, b.1, now_ms)
}

///|
/// The most recent entries (focus on empty input), newest first.
fn recent_suggestions(
  history : Array[@model.HistoryEntry],
) -> Array[@model.HistoryEntry] {
  let sorted = history.copy()
  // insertion sort by last_used_ms desc is fine for <= 100 entries
  for i in 1..<sorted.length() {
    let mut j = i
    while j > 0 && sorted[j - 1].last_used_ms < sorted[j].last_used_ms {
      let tmp = sorted[j - 1]
      sorted[j - 1] = sorted[j]
      sorted[j] = tmp
      j = j - 1
    }
  }
  first_n(sorted, SUGGESTION_LIMIT)
}

///|
/// Copy at most `n` leading items.
fn first_n(
  entries : Array[@model.HistoryEntry],
  n : Int,
) -> Array[@model.HistoryEntry] {
  let out : Array[@model.HistoryEntry] = []
  for e in entries {
    if out.length() == n {
      break
    }
    out.push(e)
  }
  out
}

///|
/// In-place ranking: score desc, then last_used_ms desc, then query asc.
fn sort_by_score(entries : Array[@model.HistoryEntry], now_ms : Int64) -> Unit {
  for i in 1..<entries.length() {
    let mut j = i
    while j > 0 && entry_before(entries[j], entries[j - 1], now_ms) {
      let tmp = entries[j - 1]
      entries[j - 1] = entries[j]
      entries[j] = tmp
      j = j - 1
    }
  }
}

///|
/// Total order: a ranks above b when score is higher, or equal score with
/// more recent use, or equal both with a smaller query string.
fn entry_before(
  a : @model.HistoryEntry,
  b : @model.HistoryEntry,
  now_ms : Int64,
) -> Bool {
  let sa = a.score(now_ms~)
  let sb = b.score(now_ms~)
  sa > sb ||
  (sa == sb && a.last_used_ms > b.last_used_ms) ||
  (sa == sb && a.last_used_ms == b.last_used_ms && a.query < b.query)
}
