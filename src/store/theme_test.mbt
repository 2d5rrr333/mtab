// Theme tests (theme-system task 1.1).

///|
fn tbase() -> @store.Store {
  @store.open(None, "2025-01-29").state
}

///|
test "theme defaults to dark and old files decode dark" {
  assert_eq(@model.Config::default().theme, "dark")
  let v2 = "{\"version\":2,\"groups\":[{\"id\":\"g0\",\"name\":\"默认分组\",\"bookmarks\":[]}],\"search\":{\"engines\":[],\"current\":\"baidu\"},\"widgets\":{\"clock\":true,\"bookmarks\":true},\"wallpaper\":{\"type\":\"builtin\",\"id\":\"w1\"}}"
  let cfg = @model.Config::decode(v2)
  assert_eq(cfg.theme, "dark")
}

///|
test "theme_set accepts all three values and saves" {
  // chain dark -> light -> auto -> dark: every step differs, every step saves
  let a = @store.update(tbase(), ThemeSet(theme="light"))
  assert_eq(a.state.config.theme, "light")
  assert_eq(a.effects, [Save])
  let b = @store.update(a.state, ThemeSet(theme="auto"))
  assert_eq(b.state.config.theme, "auto")
  assert_eq(b.effects, [Save])
  let c = @store.update(b.state, ThemeSet(theme="dark"))
  assert_eq(c.state.config.theme, "dark")
  assert_eq(c.effects, [Save])
}

///|
test "theme_set rejects invalid values and no-ops when unchanged" {
  let bad = @store.update(tbase(), ThemeSet(theme="solarized"))
  assert_true(bad.effects is [NotifyError(..)])
  assert_eq(bad.state.config.theme, "dark")
  let st = @store.update(tbase(), ThemeSet(theme="light")).state
  let same = @store.update(st, ThemeSet(theme="light"))
  assert_eq(same.effects, [])
}

///|
test "theme round-trips through JSON" {
  let cfg = { ..@model.Config::default(), theme: "auto", }
  let decoded = @model.Config::decode(cfg.encode())
  assert_eq(decoded.theme, "auto")
}
