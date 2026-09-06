// Group model tests (bookmark-groups tasks 1.1 / 1.2 / 1.3).

///|
fn bm(id : String, name : String, url : String) -> Bookmark {
  { id, name, url, }
}

///|
fn grp(id : String, name : String, bookmarks : Array[Bookmark]) -> Group {
  { id, name, bookmarks, collapsed: false, }
}

///|
test "group round-trips through JSON" {
  let g = grp("g1", "工作", [bm("b1", "示例", "https://example.com")])
  let json = ToJson::to_json(g).stringify()
  let decoded : Group = @json.from_json(@json.parse(json))
  assert_eq(decoded, g)
}

///|
test "empty groups list gets the default group" {
  let groups = ensure_groups_valid([])
  assert_eq(groups.length(), 1)
  assert_eq(groups[0].id, "g0")
  assert_eq(groups[0].name, "默认分组")
  assert_eq(groups[0].bookmarks, [])
}

///|
test "groups without g0 first get a default group prepended" {
  let groups = ensure_groups_valid([grp("g1", "A", [])])
  assert_eq(groups.length(), 2)
  assert_eq(groups[0].id, "g0")
}

///|
test "valid groups pass through unchanged" {
  let groups = [grp("g0", "默认分组", []), grp("g1", "A", [])]
  assert_eq(ensure_groups_valid(groups), groups)
}

///|
test "v1 config migrates flat bookmarks into the default group in order" {
  // exact shape of a pre-groups export file
  let v1 = "{\"version\":1,\"bookmarks\":[{\"id\":\"b1\",\"name\":\"甲\",\"url\":\"https://a.com\"},{\"id\":\"b2\",\"name\":\"乙\",\"url\":\"https://b.com\"}],\"search\":{\"engines\":[],\"current\":\"baidu\"},\"widgets\":{\"clock\":true,\"bookmarks\":true},\"wallpaper\":{\"type\":\"builtin\",\"id\":\"w1\"}}"
  let cfg = Config::decode(v1)
  assert_eq(cfg.groups.length(), 1)
  assert_eq(cfg.groups[0].id, "g0")
  assert_eq(cfg.groups[0].bookmarks.map(b => b.id), ["b1", "b2"])
}

///|
test "v2 config round-trips with groups" {
  let cfg = Config::default()
  let cfg = {
    ..cfg,
    groups: [
      make_default_group([bm("b1", "甲", "https://a.com")]),
      grp("g1", "工作", [bm("b2", "乙", "https://b.com")]),
    ],
  }
  let decoded = Config::decode(cfg.encode())
  assert_eq(decoded, cfg)
  assert_eq(decoded.version, 2)
}

///|
test "v2 with empty groups array is repaired with a default group" {
  let v2 = "{\"version\":2,\"groups\":[],\"search\":{\"engines\":[],\"current\":\"baidu\"},\"widgets\":{\"clock\":true,\"bookmarks\":true},\"wallpaper\":{\"type\":\"builtin\",\"id\":\"w1\"}}"
  let cfg = Config::decode(v2)
  assert_eq(cfg.groups.length(), 1)
  assert_eq(cfg.groups[0].id, "g0")
}

///|
test "unknown version is rejected" {
  try
    Config::decode(
      "{\"version\":3,\"groups\":[],\"search\":{\"engines\":[],\"current\":\"baidu\"},\"widgets\":{\"clock\":true,\"bookmarks\":true},\"wallpaper\":{\"type\":\"builtin\",\"id\":\"w1\"}}",
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("expected version 3 to be rejected")
  }
}

///|
test "next_group_id scans all groups" {
  let groups = [make_default_group([]), grp("g2", "A", []), grp("g5", "B", [])]
  assert_eq(next_group_id(groups), "g6")
  assert_eq(next_group_id([make_default_group([])]), "g1")
}
