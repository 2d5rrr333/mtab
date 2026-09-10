// Bookmark import merge (bookmark-import design D3): fold a parsed Netscape
// file into the existing groups. All decisions live here, not in the shell.

///|
/// Total bookmark cap after import (bookmark-import design D6 guard):
/// keeps the persisted config comfortably inside localStorage budgets.
pub const IMPORT_BOOKMARK_LIMIT : Int = 1000

///|
/// Import outcome for the reducer: the merged groups plus toast stats.
pub(all) struct ImportStats {
  mut added_groups : Int
  mut added_bookmarks : Int
  mut skipped : Int
} derive(Eq, Debug)

///|
/// Merge a parsed bookmark file into `groups` (bookmark-grid spec):
/// same-name groups merge, URLs dedupe against existing and in-batch
/// entries, new groups append after existing ones, top-level bookmarks
/// land in the default group. Invalid URLs and over-limit entries are
/// skipped and counted.
pub fn merge_import(
  groups : Array[@model.Group],
  parsed : @model.ParseResult,
) -> (Array[@model.Group], ImportStats) {
  let out : Array[@model.Group] = groups.map(g => {
    ..g,
    bookmarks: g.bookmarks.copy(),
  })
  // dedupe key set: normalized URLs of every existing bookmark
  let seen : Set[String] = Set([], capacity=64)
  for g in out {
    for b in g.bookmarks {
      seen.add(b.url)
    }
  }
  let stats : ImportStats = { added_groups: 0, added_bookmarks: 0, skipped: 0, }
  // local id counter: "b" + max existing suffix + 1, growing per addition
  let mut next_id = numeric_max_suffix(out) + 1
  // top-level entries land in the default group (always out[0] by invariant)
  for b in parsed.top {
    match accept_import(b, seen, out) {
      Some((name, url)) => {
        let bookmark : @model.Bookmark = {
          id: "b" + next_id.to_string(),
          name,
          url,
        }
        next_id = next_id + 1
        let g = out[0]
        out[0] = { ..g, bookmarks: [..g.bookmarks, bookmark], }
        stats.added_bookmarks = stats.added_bookmarks + 1
      }
      None => stats.skipped = stats.skipped + 1
    }
  }
  for pg in parsed.groups {
    // same-name merge: first existing group with the exact name wins
    let mut target_idx = -1
    for i, g in out {
      if target_idx < 0 && g.name == pg.name {
        target_idx = i
      }
    }
    if target_idx < 0 {
      out.push({
        id: @model.next_group_id(out),
        name: pg.name,
        bookmarks: [],
        collapsed: false,
      })
      target_idx = out.length() - 1
      stats.added_groups = stats.added_groups + 1
    }
    for b in pg.bookmarks {
      match accept_import(b, seen, out) {
        Some((name, url)) => {
          let bookmark : @model.Bookmark = {
            id: "b" + next_id.to_string(),
            name,
            url,
          }
          next_id = next_id + 1
          let g = out[target_idx]
          out[target_idx] = { ..g, bookmarks: [..g.bookmarks, bookmark], }
          stats.added_bookmarks = stats.added_bookmarks + 1
        }
        None => stats.skipped = stats.skipped + 1
      }
    }
  }
  (out, stats)
}

///|
/// Whether a parsed entry may be imported: URL must normalize, must not
/// duplicate existing/in-batch URLs, and the total cap must hold.
/// Returns the accepted (name, url) and registers the URL.
fn accept_import(
  b : @model.ParsedBookmark,
  seen : Set[String],
  groups : Array[@model.Group],
) -> (String, String)? {
  let total = count_bookmarks(groups)
  if total >= IMPORT_BOOKMARK_LIMIT {
    return None
  }
  match @model.normalize_url(b.url) {
    None => None
    Some(u) => {
      if seen.contains(u) {
        return None
      }
      seen.add(u)
      let name = b.name.trim().to_owned()
      Some((if name == "" { u } else { name }, u))
    }
  }
}

///|
/// Largest numeric "bN" suffix across all bookmarks.
fn numeric_max_suffix(groups : Array[@model.Group]) -> Int {
  let mut max = 0
  for g in groups {
    for b in g.bookmarks {
      let n = numeric_suffix(b.id)
      if n > max {
        max = n
      }
    }
  }
  max
}

///|
/// Toast text for the import outcome (bookmark-grid spec: report result).
fn import_toast_message(stats : ImportStats) -> String {
  if stats.added_groups == 0 && stats.added_bookmarks == 0 {
    if stats.skipped > 0 {
      "未导入新内容：跳过 " +
      stats.skipped.to_string() +
      " 条重复或无效书签"
    } else {
      "未发现可导入的书签"
    }
  } else {
    let mut msg = "导入完成：新增 " +
      stats.added_groups.to_string() +
      " 组 " +
      stats.added_bookmarks.to_string() +
      " 条书签"
    if stats.skipped > 0 {
      msg = msg +
        "，跳过 " +
        stats.skipped.to_string() +
        " 条重复或无效"
    }
    msg
  }
}
