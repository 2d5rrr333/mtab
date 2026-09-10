// Group reducer tests (bookmark-groups tasks 2.2 / 2.3 / 2.4 / 2.5).

///|
fn gbase() -> @store.Store {
  // empty default group: the shipped default config carries starter bookmarks
  empty_store("2025-01-29")
}

///|
/// Bookmark ids inside group `gid`, [] when the group is missing.
fn bm_ids(st : @store.Store, gid : String) -> Array[String] {
  for g in st.config.groups {
    if g.id == gid {
      return g.bookmarks.map(b => b.id)
    }
  }
  []
}

///|
fn group_ids(st : @store.Store) -> Array[String] {
  st.config.groups.map(g => g.id)
}

///|
fn with_work_group() -> @store.Store {
  let st = @store.update(gbase(), GroupAdd(name="工作")).state
  @store.update(
    st,
    BookmarkAdd(name="甲", url="a.example.com", group=Some("g1")),
  ).state
}

///|
test "bookmark_add into a named group lands there" {
  let st = with_work_group()
  assert_eq(bm_ids(st, "g1"), ["b1"])
  assert_eq(bm_ids(st, "g0"), [])
}

///|
test "bookmark_add into a missing group is rejected" {
  let resp = @store.update(
    gbase(),
    BookmarkAdd(name="x", url="a.com", group=Some("nope")),
  )
  assert_true(resp.effects is [NotifyError(..)])
}

///|
test "bookmark_edit can move to another group via dropdown" {
  let st = with_work_group()
  let st = @store.update(
      st,
      BookmarkAdd(name="乙", url="b.example.com", group=None),
    ).state
  let resp = @store.update(
    st,
    BookmarkEdit(
      id="b2",
      name="乙改",
      url="https://b.example.com",
      group=Some("g1"),
    ),
  )
  assert_eq(bm_ids(resp.state, "g1"), ["b1", "b2"])
  assert_eq(bm_ids(resp.state, "g0"), [])
}

///|
test "bookmark_move reorders within a group" {
  let st = with_work_group()
  let st = @store.update(
      st,
      BookmarkAdd(name="乙", url="b.com", group=Some("g1")),
    ).state
  // move b2 (index 1) to index 0
  let resp = @store.update(st, BookmarkMove(id="b2", to_group="g1", to_index=0))
  assert_eq(bm_ids(resp.state, "g1"), ["b2", "b1"])
  assert_eq(resp.effects, [Save])
}

///|
test "bookmark_move across groups removes from source" {
  let st = with_work_group()
  let resp = @store.update(st, BookmarkMove(id="b1", to_group="g0", to_index=0))
  assert_eq(bm_ids(resp.state, "g0"), ["b1"])
  assert_eq(bm_ids(resp.state, "g1"), [])
}

///|
test "bookmark_move clamps out-of-range indices" {
  let st = with_work_group()
  let resp = @store.update(
    st,
    BookmarkMove(id="b1", to_group="g0", to_index=99),
  )
  assert_eq(bm_ids(resp.state, "g0"), ["b1"])
  let neg = @store.update(
    resp.state,
    BookmarkMove(id="b1", to_group="g0", to_index=-5),
  )
  assert_eq(bm_ids(neg.state, "g0"), ["b1"])
}

///|
test "bookmark_move to a missing group is rejected, state intact" {
  let st = with_work_group()
  let resp = @store.update(st, BookmarkMove(id="b1", to_group="zz", to_index=0))
  assert_true(resp.effects is [NotifyError(..)])
  assert_eq(resp.state, st)
}

///|
test "bookmark_move of a missing id is rejected" {
  let resp = @store.update(
    gbase(),
    BookmarkMove(id="b404", to_group="g0", to_index=0),
  )
  assert_true(resp.effects is [NotifyError(..)])
}

///|
test "group_add rejects empty names and appends with fresh id" {
  let bad = @store.update(gbase(), GroupAdd(name="   "))
  assert_true(bad.effects is [NotifyError(..)])
  let resp = @store.update(gbase(), GroupAdd(name=" 工作 "))
  assert_eq(resp.state.config.groups[1].id, "g1")
  assert_eq(resp.state.config.groups[1].name, "工作")
  assert_eq(resp.effects, [Save])
}

///|
test "group_rename refuses g0, empty names, unknown ids" {
  let st = with_work_group()
  let g0 = @store.update(st, GroupRename(id="g0", name="x"))
  assert_true(g0.effects is [NotifyError(..)])
  let empty = @store.update(st, GroupRename(id="g1", name=" "))
  assert_true(empty.effects is [NotifyError(..)])
  let missing = @store.update(st, GroupRename(id="zz", name="x"))
  assert_true(missing.effects is [NotifyError(..)])
  let ok = @store.update(st, GroupRename(id="g1", name="学习"))
  assert_eq(ok.state.config.groups[1].name, "学习")
}

///|
test "group_delete falls bookmarks back into g0 in order" {
  let st = with_work_group()
  let st = @store.update(
      st,
      BookmarkAdd(name="乙", url="b.com", group=Some("g1")),
    ).state
  let resp = @store.update(st, GroupDelete(id="g1"))
  assert_eq(resp.state.config.groups.length(), 1)
  assert_eq(resp.state.config.groups[0].id, "g0")
  // both bookmarks landed in g0, order preserved
  assert_eq(bm_ids(resp.state, "g0"), ["b1", "b2"])
}

///|
test "group_delete refuses g0 and unknown ids" {
  let g0 = @store.update(gbase(), GroupDelete(id="g0"))
  assert_true(g0.effects is [NotifyError(..)])
  let zz = @store.update(gbase(), GroupDelete(id="zz"))
  assert_true(zz.effects is [NotifyError(..)])
}

///|
test "group_move reorders but keeps g0 first, clamps range" {
  // g0, g1, g2, g3
  let st = @store.update(gbase(), GroupAdd(name="一")).state
  let st = @store.update(st, GroupAdd(name="二")).state
  let st = @store.update(st, GroupAdd(name="三")).state
  // move g3 to index 1
  let resp = @store.update(st, GroupMove(id="g3", to_index=1))
  assert_eq(group_ids(resp.state), ["g0", "g3", "g1", "g2"])
  // clamp: to_index 0 -> stays right after g0; to_index 99 -> last
  let clamped_low = @store.update(st, GroupMove(id="g1", to_index=0))
  assert_eq(group_ids(clamped_low.state), ["g0", "g1", "g2", "g3"])
  let clamped_high = @store.update(st, GroupMove(id="g1", to_index=99))
  assert_eq(group_ids(clamped_high.state), ["g0", "g2", "g3", "g1"])
}

///|
test "config_import accepts v1 files (migrated) and rejects v3" {
  let v1 = "{\"version\":1,\"bookmarks\":[{\"id\":\"b1\",\"name\":\"甲\",\"url\":\"https://a.com\"}],\"search\":{\"engines\":[],\"current\":\"baidu\"},\"widgets\":{\"clock\":true,\"bookmarks\":true},\"wallpaper\":{\"type\":\"builtin\",\"id\":\"w1\"}}"
  let resp = @store.update(gbase(), ConfigImport(json=v1))
  assert_eq(resp.effects, [Save])
  assert_eq(bm_ids(resp.state, "g0"), ["b1"])
  let v3 = "{\"version\":3,\"groups\":[],\"search\":{\"engines\":[],\"current\":\"baidu\"},\"widgets\":{\"clock\":true,\"bookmarks\":true},\"wallpaper\":{\"type\":\"builtin\",\"id\":\"w1\"}}"
  let bad = @store.update(gbase(), ConfigImport(json=v3))
  assert_true(bad.effects is [NotifyError(..)])
}
