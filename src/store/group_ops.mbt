// Group/nested-array operations for the reducer (bookmark-groups design D2).
// All operations return fresh arrays; nothing mutates in place.

///|
/// Whether a group with this id exists.
fn group_exists(groups : Array[@model.Group], id : String) -> Bool {
  groups.any(g => g.id == id)
}

///|
/// Total bookmark count across all groups.
fn count_bookmarks(groups : Array[@model.Group]) -> Int {
  let mut n = 0
  for g in groups {
    n = n + g.bookmarks.length()
  }
  n
}

///|
/// Fresh groups array with every group mapped by `f`.
fn map_all_groups(
  groups : Array[@model.Group],
  f : (@model.Group) -> @model.Group,
) -> Array[@model.Group] {
  let out : Array[@model.Group] = []
  for g in groups {
    out.push(f(g))
  }
  out
}

///|
/// Fresh groups array with only group `id` replaced by `f(group)`;
/// other groups are shared as-is (structural sharing on immutable use).
fn map_groups(
  groups : Array[@model.Group],
  id : String,
  f : (@model.Group) -> @model.Group,
) -> Array[@model.Group] {
  map_all_groups(groups, g => if g.id == id { f(g) } else { g })
}

///|
/// Edit bookmark `id` (name/url) and optionally move it to `to_group`
/// (appended at that group's end). None when the bookmark is not found.
fn edit_bookmark(
  groups : Array[@model.Group],
  id : String,
  name : String,
  url : String,
  to_group : String?,
) -> Array[@model.Group]? {
  // locate the bookmark first
  let mut found_gid = ""
  let mut found : @model.Bookmark? = None
  for g in groups {
    for b in g.bookmarks {
      if b.id == id {
        found_gid = g.id
        found = Some(b)
      }
    }
  }
  match found {
    None => None
    Some(b) => {
      let updated : @model.Bookmark = { ..b, name, url, }
      let target = match to_group {
        Some(gid) => gid
        None => found_gid
      }
      // remove from the source group, append to the target group
      let stripped = map_groups(groups, found_gid, g => {
        ..g,
        bookmarks: g.bookmarks.filter(x => x.id != id),
      })
      Some(
        map_groups(stripped, target, g => {
          let bookmarks = g.bookmarks.copy()
          bookmarks.push(updated)
          { ..g, bookmarks, }
        }),
      )
    }
  }
}

///|
/// Move bookmark `id` into `to_group` at `to_index` (clamped to the
/// target's valid range). Works for in-group reorder and cross-group
/// moves alike. None when the bookmark is not found.
fn move_bookmark(
  groups : Array[@model.Group],
  id : String,
  to_group : String,
  to_index : Int,
) -> Array[@model.Group]? {
  let mut found_gid = ""
  let mut found : @model.Bookmark? = None
  for g in groups {
    for b in g.bookmarks {
      if b.id == id {
        found_gid = g.id
        found = Some(b)
      }
    }
  }
  match found {
    None => None
    Some(b) => {
      // remove first (so same-group index refers to the post-removal list)
      let stripped = map_groups(groups, found_gid, g => {
        ..g,
        bookmarks: g.bookmarks.filter(x => x.id != id),
      })
      let target_len = group_len(stripped, to_group)
      let mut idx = if to_index < 0 { 0 } else { to_index }
      if idx > target_len {
        idx = target_len
      }
      Some(
        map_groups(stripped, to_group, g => {
          let bookmarks = g.bookmarks.copy()
          bookmarks.insert(idx, b)
          { ..g, bookmarks, }
        }),
      )
    }
  }
}

///|
fn group_len(groups : Array[@model.Group], id : String) -> Int {
  for g in groups {
    if g.id == id {
      return g.bookmarks.length()
    }
  }
  0
}

///|
/// Rename group `id`. None when the group is not found.
fn rename_group(
  groups : Array[@model.Group],
  id : String,
  name : String,
) -> Array[@model.Group]? {
  if !group_exists(groups, id) {
    return None
  }
  Some(map_groups(groups, id, g => { ..g, name, }))
}

///|
/// Delete group `id`; its bookmarks are appended (in order) to the default
/// group. None when the group is not found.
fn delete_group(
  groups : Array[@model.Group],
  id : String,
) -> Array[@model.Group]? {
  let mut victim : @model.Group? = None
  for g in groups {
    if g.id == id {
      victim = Some(g)
    }
  }
  match victim {
    None => None
    Some(v) => {
      let remaining = groups.filter(g => g.id != id)
      Some(
        map_groups(remaining, @model.DEFAULT_GROUP_ID, g => {
          let bookmarks = g.bookmarks.copy()
          for b in v.bookmarks {
            bookmarks.push(b)
          }
          { ..g, bookmarks, }
        }),
      )
    }
  }
}

///|
/// Move group `id` to absolute index `to_index`, clamped to [1, len-1]:
/// the default group always stays first (bookmark-groups design D2).
/// None when the group is not found.
fn move_group(
  groups : Array[@model.Group],
  id : String,
  to_index : Int,
) -> Array[@model.Group]? {
  if !group_exists(groups, id) {
    return None
  }
  let len = groups.length()
  // final absolute position, clamped to [1, len-1] (g0 stays at 0)
  let mut slot = if to_index < 1 { 1 } else { to_index }
  if slot > len - 1 {
    slot = len - 1
  }
  let out = groups.copy()
  // locate and remove the moved group
  let mut idx = -1
  for i, g in out {
    if g.id == id {
      idx = i
    }
  }
  if idx < 0 {
    return None
  }
  let moved = out[idx]
  ignore(out.remove(idx))
  // after removal the array holds len-1 groups; the moved group's final
  // position is `slot`, so insert at min(slot, len-1) in the current array
  // (when the group came from before `slot`, inserting at `slot` is right;
  // when it came from after, `slot` already points one past the gap).
  out.insert(slot, moved)
  Some(out)
}
