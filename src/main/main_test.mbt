// Blackbox protocol tests: the wasm exports' wire format at the moon
// layer, asserted with @moonwebtest/check. The bridge session is global,
// and tests in a package run in declaration order — so the uninitialized
// path must come first (the Node e2e re-covers it with a fresh instance,
// where ordering cannot interfere).

///|
test "mtab_dispatch before init answers the null-state error envelope" {
  let env = @check.parse_envelope(
    mtab_dispatch("{\"type\":\"bookmark_add\",\"name\":\"x\",\"url\":\"y\"}"),
  )
  assert_true(env is Some({ state: None, effects: _, }))
  if env is Some({ effects, .. }) {
    assert_eq(@check.effect_types(effects), ["notify_error"])
    assert_true(
      @check.find_effect(effects, "notify_error")
      is Some(Object({ "message": String("未初始化"), .. })),
    )
  }
}

///|
test "mtab_init returns a well-formed envelope" {
  let env = @check.parse_envelope(mtab_init("", "2025-01-29"))
  assert_true(env is Some({ state: Some(_), effects: _, }))
  if env is Some({ state, effects, }) {
    assert_true(
      state is Some({ "config": { "version": Number(_, ..), .. }, .. }),
    )
    assert_true(effects.length() == 0)
  }
}

///|
test "garbage event echoes the current state with notify_error" {
  mtab_init("", "2025-01-29") |> ignore
  let env = @check.parse_envelope(mtab_dispatch("not json"))
  assert_true(env is Some({ state: Some({ "config": _, .. }), .. }))
  if env is Some({ effects, .. }) {
    assert_eq(@check.effect_types(effects), ["notify_error"])
    assert_true(
      @check.find_effect(effects, "notify_error")
      is Some(Object({ "message": String("无效的事件"), .. })),
    )
  }
}

///|
test "a valid event reduces to a save effect on the wire" {
  let env = @check.parse_envelope(
    mtab_dispatch(
      "{\"type\":\"bookmark_add\",\"name\":\"示例\",\"url\":\"example.com\"}",
    ),
  )
  if env is Some({ effects, .. }) {
    assert_eq(@check.effect_types(effects), ["save"])
  }
}
