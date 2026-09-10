// Countdown reducer tests (countdown-widget tasks 2.1 / 2.2 / 2.3 / 2.4).

///|
test "countdown events decode from bridge JSON (task 2.2)" {
  let add : Event = @json.from_json(
    @json.parse(
      "{\"type\":\"countdown_add\",\"name\":\"生日\",\"date\":\"2026-12-01\"}",
    ),
  )
  assert_eq(add, CountdownAdd(name="生日", date="2026-12-01"))
  let del : Event = @json.from_json(
    @json.parse("{\"type\":\"countdown_delete\",\"id\":\"c1\"}"),
  )
  assert_eq(del, CountdownDelete(id="c1"))
}

///|
test "open seeds today and an empty countdown view (task 2.1)" {
  let resp = @store.open(None, "2026-09-10")
  assert_eq(resp.state.today, "2026-09-10")
  assert_eq(resp.state.countdown_views, [])
}

///|
test "countdown_add validates and appends in order (task 2.3)" {
  let base = @store.open(None, "2026-09-10").state
  let ok = @store.update(base, CountdownAdd(name="生日", date="2026-12-01"))
  assert_eq(ok.state.config.countdowns.length(), 1)
  assert_eq(ok.state.config.countdowns[0].id, "c1")
  assert_eq(ok.state.config.countdowns[0].name, "生日")
  assert_eq(ok.effects, [Save])
  assert_eq(ok.state.countdown_views, [{ id: "c1", name: "生日", days: 82, }])
  // name trimming: spaces only is rejected; padded name is trimmed
  let blank = @store.update(base, CountdownAdd(name="   ", date="2026-12-01"))
  assert_true(blank.effects is [NotifyError(..)])
  let padded = @store.update(
    base,
    CountdownAdd(name="  考试  ", date="2026-10-01"),
  )
  assert_eq(padded.state.config.countdowns[0].name, "考试")
}

///|
test "countdown_add rejects impossible dates (task 2.3)" {
  let base = @store.open(None, "2026-09-10").state
  let bad = @store.update(base, CountdownAdd(name="坏", date="2026-02-30"))
  assert_true(bad.effects is [NotifyError(..)])
  assert_eq(bad.state.config.countdowns, [])
  let shaped = @store.update(base, CountdownAdd(name="坏", date="2026/12/01"))
  assert_true(shaped.effects is [NotifyError(..)])
}

///|
test "countdown_delete removes or notifies (task 2.3)" {
  let base = @store.open(None, "2026-09-10").state
  let with_cd = @store.update(
      base,
      CountdownAdd(name="生日", date="2026-12-01"),
    ).state
  let gone = @store.update(with_cd, CountdownDelete(id="c1"))
  assert_eq(gone.state.config.countdowns, [])
  assert_eq(gone.state.countdown_views, [])
  assert_eq(gone.effects, [Save])
  let missing = @store.update(with_cd, CountdownDelete(id="zz"))
  assert_true(missing.effects is [NotifyError(..)])
}

///|
test "widget_toggle countdown round-trips and persists (task 2.3)" {
  let base = @store.open(None, "2026-09-10").state
  assert_false(base.config.widgets.countdown) // default off (spec)
  let on = @store.update(base, WidgetToggle(widget="countdown"))
  assert_true(on.state.config.widgets.countdown)
  assert_eq(on.effects, [Save])
  let off = @store.update(on.state, WidgetToggle(widget="countdown"))
  assert_false(off.state.config.widgets.countdown)
}

///|
test "tick_date recomputes countdown views without saving (task 2.4)" {
  // today 2026-09-10, target 2026-09-11: 1 day remains
  let base = @store.open(None, "2026-09-10").state
  let with_cd = @store.update(
      base,
      CountdownAdd(name="明天", date="2026-09-11"),
    ).state
  assert_eq(with_cd.countdown_views[0].days, 1)
  // day rolls over to the target day: 0 = is today
  let rolled = @store.update(with_cd, TickDate(date="2026-09-11"))
  assert_eq(rolled.state.today, "2026-09-11")
  assert_eq(rolled.state.countdown_views[0].days, 0)
  assert_eq(rolled.effects, []) // view-only: no save
  // one more day: negative = past
  let past = @store.update(rolled.state, TickDate(date="2026-09-13"))
  assert_eq(past.state.countdown_views[0].days, -2)
}

///|
test "config import keeps today and recomputes countdown views" {
  let base = @store.open(None, "2026-09-10").state
  let with_cd = @store.update(
      base,
      CountdownAdd(name="考试", date="2026-10-01"),
    ).state
  let exported = with_cd.config.encode()
  let fresh = @store.open(Some(exported), "2026-09-15").state
  assert_eq(fresh.today, "2026-09-15")
  assert_eq(fresh.countdown_views, [{ id: "c1", name: "考试", days: 16, }])
  // and through the event path
  let reimported = @store.update(fresh, ConfigImport(json=exported))
  assert_eq(reimported.state.countdown_views[0].days, 16)
}
