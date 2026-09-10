// Countdown model tests (countdown-widget tasks 1.1 / 1.2 / 1.3).

///|
test "gregorian_day_number date differences (task 1.1)" {
  // plain days
  assert_eq(
    @lunar.gregorian_day_number(2026, 9, 13) -
    @lunar.gregorian_day_number(2026, 9, 10),
    3,
  )
  // non-leap february: 02-28 -> 03-01 is 1 day
  assert_eq(
    @lunar.gregorian_day_number(2027, 3, 1) -
    @lunar.gregorian_day_number(2027, 2, 28),
    1,
  )
  // leap february (2028): 02-28 -> 03-01 is 2 days
  assert_eq(
    @lunar.gregorian_day_number(2028, 3, 1) -
    @lunar.gregorian_day_number(2028, 2, 28),
    2,
  )
  // full-year cross
  assert_eq(
    @lunar.gregorian_day_number(2027, 9, 10) -
    @lunar.gregorian_day_number(2026, 9, 10),
    365,
  )
}

///|
test "parse_countdown_date accepts real calendar dates" {
  assert_true(@model.parse_countdown_date("2026-12-01") is Some((2026, 12, 1)))
  assert_true(@model.parse_countdown_date("2028-02-29") is Some((2028, 2, 29)))
}

///|
test "parse_countdown_date rejects bad shapes and impossible dates" {
  assert_true(@model.parse_countdown_date("2026-02-30") is None) // no such day
  assert_true(@model.parse_countdown_date("2026-13-01") is None) // month
  assert_true(@model.parse_countdown_date("2026-00-10") is None) // month
  assert_true(@model.parse_countdown_date("2026-09-00") is None) // day
  assert_true(@model.parse_countdown_date("2027-02-29") is None) // non-leap
  assert_true(@model.parse_countdown_date("2026/12/01") is None) // separator
  assert_true(@model.parse_countdown_date("26-12-01") is None) // year shape
  assert_true(@model.parse_countdown_date("") is None)
  assert_true(@model.validate_countdown_date("2026-12-01"))
  assert_false(@model.validate_countdown_date("2026-02-30"))
}

///|
test "remaining_days sign semantics" {
  assert_eq(@model.remaining_days("2026-09-13", "2026-09-10"), Some(3))
  assert_eq(@model.remaining_days("2026-09-10", "2026-09-10"), Some(0))
  assert_eq(@model.remaining_days("2026-09-08", "2026-09-10"), Some(-2))
  // cross-year and leap-year correctness via day numbers
  assert_eq(@model.remaining_days("2027-03-01", "2027-02-28"), Some(1))
  assert_eq(@model.remaining_days("2028-03-01", "2028-02-28"), Some(2))
  // invalid inputs yield None
  assert_true(@model.remaining_days("2026-02-30", "2026-09-10") is None)
  assert_true(@model.remaining_days("2026-09-13", "not-a-date") is None)
}

///|
test "countdown json round-trip" {
  let c : @model.Countdown = { id: "c1", name: "生日", date: "2026-12-01", }
  let json = ToJson::to_json(c).stringify()
  let decoded : @model.Countdown = @json.from_json(@json.parse(json))
  assert_eq(decoded, c)
}

///|
test "config round-trips countdowns and writes the key (task 1.3)" {
  let cfg = @model.Config::default()
  let with_cd = {
    ..cfg,
    countdowns: [{ id: "c1", name: "考试", date: "2026-10-01", }],
  }
  let decoded : @model.Config = @json.from_json(
    @json.parse(ToJson::to_json(with_cd).stringify()),
  )
  assert_eq(decoded.countdowns, with_cd.countdowns)
  assert_true(ToJson::to_json(cfg).stringify().contains("\"countdowns\""))
}

///|
test "old config without countdown fields decodes to defaults" {
  // v2 file without countdowns key, widgets without countdown key
  let legacy : Json = {
    "version": 2,
    "groups": [],
    "search": { "engines": [], "current": "baidu", "history": [] },
    "widgets": { "clock": true, "bookmarks": true },
    "wallpaper": { "type": "builtin", "id": "w1" },
  }
  let decoded : @model.Config = @json.from_json(@json.parse(legacy.stringify()))
  assert_eq(decoded.countdowns, [])
  assert_false(decoded.widgets.countdown)
}

///|
test "widgets countdown switch decodes explicit values" {
  let on : Json = { "clock": true, "bookmarks": true, "countdown": true }
  let w : @model.WidgetsConfig = @json.from_json(@json.parse(on.stringify()))
  assert_true(w.countdown)
  assert_true(ToJson::to_json(w).stringify().contains("\"countdown\":true"))
}
