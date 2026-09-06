// Bookmark groups (bookmark-groups design D1): nested arrays carry both
// group order and in-group order; no separate order fields.

///|
/// The id of the fixed default group. Always groups[0]; cannot be deleted
/// or renamed; bookmarks of deleted groups fall back into it.
pub const DEFAULT_GROUP_ID : String = "g0"

///|
/// A bookmark group: a named, ordered list of bookmarks.
pub(all) struct Group {
  id : String
  name : String
  bookmarks : Array[Bookmark]
} derive(Eq, Debug)

///|
/// Build the default group carrying `bookmarks` (v1 migration landing
/// spot, bookmark fallback target).
pub fn make_default_group(bookmarks : Array[Bookmark]) -> Group {
  { id: DEFAULT_GROUP_ID, name: "默认分组", bookmarks, }
}

///|
/// Enforce the groups invariant: at least one group, first one being the
/// default group. An empty (or default-less) list gets a fresh empty
/// default group; otherwise the list is returned as-is.
pub fn ensure_groups_valid(groups : Array[Group]) -> Array[Group] {
  if groups.length() == 0 {
    return [make_default_group([])]
  }
  if groups[0].id != DEFAULT_GROUP_ID {
    return [make_default_group([]), ..groups]
  }
  groups
}

///|
/// Generate a fresh group id ("g" + next number above all existing ones;
/// g0 is always present and never returned here).
pub fn next_group_id(groups : Array[Group]) -> String {
  let mut max = 0
  for g in groups {
    let n = numeric_gid_suffix(g.id)
    if n > max {
      max = n
    }
  }
  "g" + (max + 1).to_string()
}

///|
/// Numeric suffix of a "gN" id ("g12" -> 12); anything else yields 0.
fn numeric_gid_suffix(s : String) -> Int {
  if s.length() < 2 {
    return 0
  }
  let mut n = 0
  for i in 1..<s.length() {
    let c = s[i]
    if c < '0' || c > '9' {
      return 0
    }
    n = n * 10 + (c.to_int() - '0'.to_int())
  }
  n
}

///|
pub impl ToJson for Group with fn to_json(self) {
  { "id": self.id, "name": self.name, "bookmarks": self.bookmarks }
}

///|
pub impl FromJson for Group with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> Group raise @json.JsonDecodeError {
  let map = expect_object(json, path)
  let bookmarks : Array[Bookmark] = []
  for i, item in array_field(map, "bookmarks", path) {
    bookmarks.push(@json.from_json(item, path=path.add_index(i)))
  }
  {
    id: str_field(map, "id", path),
    name: str_field(map, "name", path),
    bookmarks,
  }
}
