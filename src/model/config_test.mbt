// Config model round-trip and validation tests (tasks 2.1).

///|
test "default config ships starter bookmarks in the default group" {
  let cfg = Config::default()
  assert_eq(cfg.groups.length(), 1)
  assert_eq(cfg.groups[0].id, DEFAULT_GROUP_ID)
  assert_eq(cfg.groups[0].bookmarks.length(), 6)
  assert_eq(cfg.groups[0].bookmarks.map(b => b.id), [
    "b1", "b2", "b3", "b4", "b5", "b6",
  ])
  assert_eq(cfg.groups[0].bookmarks[0].url, "https://www.baidu.com")
}

///|
test "default config round-trips through JSON" {
  let cfg = Config::default()
  let encoded = cfg.encode()
  let decoded = Config::decode(encoded)
  assert_eq(decoded, cfg)
}

///|
test "decode accepts the design D6 example shape" {
  let json : Json = {
    "version": 1,
    "bookmarks": [
      { "id": "b1", "name": "示例", "url": "https://example.com" },
    ],
    "search": {
      "engines": [
        {
          "id": "baidu",
          "name": "百度",
          "urlTemplate": "https://www.baidu.com/s?wd={query}",
        },
      ],
      "current": "baidu",
    },
    "widgets": { "clock": true, "bookmarks": false },
    "wallpaper": { "type": "builtin", "id": "w2" },
  }
  let decoded = Config::decode(json.stringify())
  assert_eq(decoded.version, 1)
  // v1 shape migrates into the default group (bookmark-groups D1)
  assert_eq(decoded.groups.length(), 1)
  assert_eq(decoded.groups[0].bookmarks.length(), 1)
  assert_eq(decoded.groups[0].bookmarks[0].name, "示例")
  assert_eq(decoded.widgets.clock, true)
  assert_eq(decoded.widgets.bookmarks, false)
  assert_true(decoded.wallpaper is Builtin("w2"))
}

///|
test "custom wallpaper round-trips with embedded data" {
  let cfg = Config::default()
  let cfg = { ..cfg, wallpaper: Custom("data:image/jpeg;base64,QUJD"), }
  let decoded = Config::decode(cfg.encode())
  assert_true(decoded.wallpaper is Custom("data:image/jpeg;base64,QUJD"))
}

///|
test "invalid JSON raises instead of crashing" {
  try Config::decode("not json {") catch {
    _ => () // expected: parse error
  } noraise {
    _ => fail("expected invalid JSON to raise")
  }
}

///|
test "wrong structure raises instead of crashing" {
  try Config::decode("{\"version\":1,\"bookmarks\":42}") catch {
    _ => () // expected: decode error
  } noraise {
    _ => fail("expected wrong structure to raise")
  }
}

///|
test "missing field raises" {
  try Config::decode("{\"version\":1}") catch {
    _ => () // expected: missing fields
  } noraise {
    _ => fail("expected missing fields to raise")
  }
}
