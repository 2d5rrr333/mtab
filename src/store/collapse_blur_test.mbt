// Group collapse + wallpaper blur tests (group-collapse-blur task 1.1/1.2).

///|
fn cbbase() -> @store.Store {
  @store.open(None, "2025-01-29").state
}

///|
test "old v2 group without collapsed decodes expanded" {
  let v2 = "{\"version\":2,\"groups\":[{\"id\":\"g0\",\"name\":\"榛樿鍒嗙粍\",\"bookmarks\":[]}],\"search\":{\"engines\":[],\"current\":\"baidu\"},\"widgets\":{\"clock\":true,\"bookmarks\":true},\"wallpaper\":{\"type\":\"builtin\",\"id\":\"w1\"}}"
  let cfg = @model.Config::decode(v2)
  assert_false(cfg.groups[0].collapsed)
  assert_eq(cfg.wallpaper_blur, 0)
}

///|
test "collapsed and blur round-trip through JSON" {
  let cfg = @model.Config::default()
  let cfg = {
    ..cfg,
    groups: [{ ..cfg.groups[0], collapsed: true, }],
    wallpaper_blur: 8,
  }
  let decoded = @model.Config::decode(cfg.encode())
  assert_true(decoded.groups[0].collapsed)
  assert_eq(decoded.wallpaper_blur, 8)
}

///|
test "group_toggle_collapse flips and saves" {
  let st = @store.update(cbbase(), GroupAdd(name="宸ヤ綔")).state
  let resp = @store.update(st, GroupToggleCollapse(id="g1"))
  assert_true(resp.state.config.groups[1].collapsed)
  assert_eq(resp.effects, [Save])
  let back = @store.update(resp.state, GroupToggleCollapse(id="g1"))
  assert_false(back.state.config.groups[1].collapsed)
}

///|
test "group_toggle_collapse works on g0 and rejects missing ids" {
  let resp = @store.update(cbbase(), GroupToggleCollapse(id="g0"))
  assert_true(resp.state.config.groups[0].collapsed)
  let bad = @store.update(cbbase(), GroupToggleCollapse(id="zz"))
  assert_true(bad.effects is [NotifyError(..)])
}

///|
test "wallpaper_blur_set clamps both ends" {
  let low = @store.update(cbbase(), WallpaperBlurSet(amount=-5))
  assert_eq(low.state.config.wallpaper_blur, 0)
  let high = @store.update(cbbase(), WallpaperBlurSet(amount=99))
  assert_eq(high.state.config.wallpaper_blur, 20)
  assert_eq(high.effects, [Save])
}

///|
test "wallpaper_blur_set is a no-op when unchanged" {
  let st = @store.update(cbbase(), WallpaperBlurSet(amount=8)).state
  let again = @store.update(st, WallpaperBlurSet(amount=8))
  assert_eq(again.effects, [])
  assert_eq(again.state, st)
}
