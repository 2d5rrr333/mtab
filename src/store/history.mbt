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
/// last_used_ms; otherwise trie prefix matches (case-insensitive) ranked
/// by score, then by last_used_ms, then by query for determinism.
fn suggest_for(
  history : Array[@model.HistoryEntry],
  query : String,
  now_ms : Int64,
) -> Array[@model.HistoryEntry] {
  let trimmed = query.trim().to_owned()
  if trimmed == "" {
    return recent_suggestions(history)
  }
  // Build a trie over lowercased queries, id = query text itself.
  let trie = @trie.Trie::new()
  for e in history {
    trie.insert(e.query.to_lower(), e.query)
  }
  let ids = trie.prefix_query(trimmed.to_lower())
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
