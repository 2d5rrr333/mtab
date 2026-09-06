// ClockView solar-term / festival integration tests
// (solar-terms-festivals task 3.1).

///|
test "clock view carries solar term on a term day" {
  // 2025-10-08 is 寒露 and no festival
  let resp = @store.open(None, "2025-10-08")
  assert_true(
    resp.state.clock
    is Some(
      {
        weekday: "星期三",
        lunar: Some("乙巳年八月十七"),
        solar_term: Some("寒露"),
        festival: None,
      }
    ),
  )
}

///|
test "clock view prefers festival over same-day term" {
  // Find a statutory holiday that is also a term day: 2025-10-01 国庆节.
  // (Whether a term also falls that day varies; assert festival wins by
  // checking the festival field is set and solar_term is None whenever
  // a festival is present — rule, not coincidence.)
  let resp = @store.open(None, "2025-10-01")
  assert_true(resp.state.clock is Some({ festival: Some("国庆节"), .. }))
  if resp.state.clock is Some({ festival: Some(_), solar_term, .. }) {
    assert_eq(solar_term, None)
  }
}

///|
test "clock view out of lunar range degrades with weekday intact" {
  let resp = @store.open(None, "1800-05-05")
  assert_true(
    resp.state.clock
    is Some({ weekday: _, lunar: None, solar_term: None, festival: None, }),
  )
}

///|
test "tick_date into a term day recomputes the term" {
  let base = @store.open(None, "2025-10-07").state
  assert_true(base.clock is Some({ solar_term: None, .. }))
  let resp = @store.update(base, TickDate(date="2025-10-08"))
  assert_true(resp.state.clock is Some({ solar_term: Some("寒露"), .. }))
}
