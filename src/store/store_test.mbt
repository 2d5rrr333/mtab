// Store tests (tasks 2.3, 2.4, 3.2): one assertion set per event kind.

///|
test "open with no stored config yields the default config" {
  let resp = @store.open(None, "2025-01-29")
  assert_eq(resp.state.config, @model.Config::default())
  assert_eq(resp.effects.length(), 0)
}

///|
test "open computes weekday and lunar for today (task 3.2)" {
  let resp = @store.open(None, "2025-01-29")
  assert_true(
    resp.state.clock // festival wins the display slot
    is Some(
      {
        weekday: "星期三",
        lunar: Some("乙巳年正月初一"),
        festival: Some("春节"),
        solar_term: None,
      }
    ),
  )
}

///|
test "tick_date recomputes the clock without saving (task 3.2)" {
  let base = @store.open(None, "2025-01-29").state
  let resp = @store.update(base, TickDate(date="2025-07-25"))
  assert_true(
    resp.state.clock // 2025-07-25 (闰六月初一) is not a term day
    is Some(
      {
        weekday: "星期五",
        lunar: Some("乙巳年闰六月初一"),
        festival: None,
        solar_term: None,
      }
    ),
  )
  assert_eq(resp.effects, [])
  // Display-only: config untouched.
  assert_eq(resp.state.config, base.config)
}

///|
test "tick_date outside lunar range still shows the weekday" {
  let base = @store.open(None, "2025-01-29").state
  let resp = @store.update(base, TickDate(date="1800-05-05"))
  assert_true(resp.state.clock is Some({ lunar: None, .. }))
  let broken = @store.update(base, TickDate(date="not-a-date"))
  assert_true(broken.state.clock is None)
}

///|
test "bookmark_add normalizes the url and requests a save" {
  let base = @store.open(None, "2025-01-29").state
  let resp = @store.update(base, BookmarkAdd(name="示例", url="example.com"))
  let b = resp.state.config.bookmarks[0]
  assert_eq(b.name, "示例")
  assert_eq(b.url, "https://example.com")
  assert_eq(resp.effects, [Save])
}

///|
test "bookmark_add rejects an invalid url with a notification" {
  let base = @store.open(None, "2025-01-29").state
  let resp = @store.update(base, BookmarkAdd(name="坏", url="not a url"))
  assert_true(resp.effects is [NotifyError(..)])
  assert_eq(resp.state, base)
}

///|
test "bookmark_edit updates name and url in place" {
  let base = @store.open(None, "2025-01-29").state
  let added = @store.update(base, BookmarkAdd(name="示例", url="example.com")).state
  let resp = @store.update(
    added,
    BookmarkEdit(id="b1", name="新名", url="https://new.example.com"),
  )
  let b = resp.state.config.bookmarks[0]
  assert_eq(b.name, "新名")
  assert_eq(b.url, "https://new.example.com")
  assert_eq(resp.effects, [Save])
}

///|
test "consecutive adds get distinct ids (browser harness regression)" {
  let base = @store.open(None, "2025-01-29").state
  let one = @store.update(base, BookmarkAdd(name="一", url="a.example.com")).state
  let two = @store.update(one, BookmarkAdd(name="二", url="b.example.com")).state
  let ids = two.config.bookmarks.map(b => b.id)
  assert_eq(ids, ["b1", "b2"])
  // Deleting one leaves the other intact.
  let rest = @store.update(two, BookmarkDelete(id="b1")).state
  assert_eq(rest.config.bookmarks.map(b => b.id), ["b2"])
}

///|
test "bookmark_delete removes the bookmark" {
  let base = @store.open(None, "2025-01-29").state
  let added = @store.update(base, BookmarkAdd(name="示例", url="example.com")).state
  let resp = @store.update(added, BookmarkDelete(id="b1"))
  assert_eq(resp.state.config.bookmarks.length(), 0)
  assert_eq(resp.effects, [Save])
  // Deleting a missing id is a no-op without a save.
  let noop = @store.update(added, BookmarkDelete(id="b404"))
  assert_eq(noop.effects.length(), 0)
}

///|
test "engine_select switches the current engine and saves" {
  let base = @store.open(None, "2025-01-29").state
  let resp = @store.update(base, EngineSelect(id="google"))
  assert_eq(resp.state.config.search.current, "google")
  assert_eq(resp.effects, [Save])
  // Unknown engine id is rejected.
  let bad = @store.update(base, EngineSelect(id="duckduckgo"))
  assert_true(bad.effects is [NotifyError(..)])
  assert_eq(bad.state, base)
}

///|
test "search_submit builds the engine url for the current engine" {
  let base = @store.open(None, "2025-01-29").state
  // Default engine is baidu.
  let resp = @store.update(base, SearchSubmit(query="moonbit 语言", at=None))
  assert_eq(resp.effects, [
    OpenUrl(url="https://www.baidu.com/s?wd=moonbit%20%E8%AF%AD%E8%A8%80"),
  ])
}

///|
test "search_submit uses the selected engine after a switch" {
  let base = @store.open(None, "2025-01-29").state
  let switched = @store.update(base, EngineSelect(id="google")).state
  let resp = @store.update(switched, SearchSubmit(query="moonbit", at=None))
  assert_eq(resp.effects, [
    OpenUrl(url="https://www.google.com/search?q=moonbit"),
  ])
}

///|
test "search_submit with an empty keyword does nothing" {
  let base = @store.open(None, "2025-01-29").state
  let resp = @store.update(base, SearchSubmit(query="   ", at=None))
  assert_eq(resp.effects, [])
}

///|
test "widget_toggle flips a switch and saves (task 2.4)" {
  let base = @store.open(None, "2025-01-29").state
  let off = @store.update(base, WidgetToggle(widget="clock"))
  assert_eq(off.state.config.widgets.clock, false)
  assert_eq(off.effects, [Save])
  let on = @store.update(off.state, WidgetToggle(widget="clock"))
  assert_eq(on.state.config.widgets.clock, true)
  assert_eq(on.effects, [Save])
  // Unknown widget is a no-op.
  let noop = @store.update(base, WidgetToggle(widget="weather"))
  assert_eq(noop.state, base)
}

///|
test "wallpaper_set_builtin and wallpaper_set_custom update and save" {
  let base = @store.open(None, "2025-01-29").state
  let builtin = @store.update(base, WallpaperSetBuiltin(id="w3"))
  assert_true(builtin.state.config.wallpaper is @model.Builtin("w3"))
  assert_eq(builtin.effects, [Save])
  let custom = @store.update(
    base,
    WallpaperSetCustom(data="data:image/jpeg;base64,QUJD"),
  )
  assert_true(custom.state.config.wallpaper is @model.Custom(_))
  assert_eq(custom.effects, [Save])
}

///|
test "config_import replaces the whole config and saves (task 2.4)" {
  let base = @store.open(None, "2025-01-29").state
  let other = @model.Config::default()
  let other = { ..other, widgets: { clock: false, bookmarks: false, }, }
  let resp = @store.update(base, ConfigImport(json=other.encode()))
  assert_eq(resp.state.config, other)
  assert_eq(resp.effects, [Save])
}

///|
test "config_import rejects invalid files and unknown versions" {
  let base = @store.open(None, "2025-01-29").state
  let bad = @store.update(base, ConfigImport(json="{{not json"))
  assert_true(bad.effects is [NotifyError(..)])
  assert_eq(bad.state, base)
  let versioned = "{\"version\": 99}"
  let wrong = @store.update(base, ConfigImport(json=versioned))
  assert_true(wrong.effects is [NotifyError(..)])
  assert_eq(wrong.state, base)
}

///|
test "open falls back to the default config on undecodable storage" {
  let resp = @store.open(Some("{\"version\":1,"), "2025-01-29")
  assert_eq(resp.state.config, @model.Config::default())
}

///|
test "open restores a previously stored config" {
  let cfg = @model.Config::default()
  let cfg = { ..cfg, search: { ..cfg.search, current: "bing", }, }
  let resp = @store.open(Some(cfg.encode()), "2025-01-29")
  assert_eq(resp.state.config, cfg)
}
