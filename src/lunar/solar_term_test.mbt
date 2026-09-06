// Solar-term anchor tests (solar-terms-festivals task 1.1/1.2/1.3).
// Anchor dates are known jieqi days in Beijing time, cross-checked
// against the Chinese perpetual calendar.

///|
test "anchor: 2025 known term days" {
  // 2025: 清明 4-04, 夏至 6-21, 寒露 10-08, 冬至 12-21, 立春 2-03
  assert_eq(solar_term(2025, 4, 4), Some("清明"))
  assert_eq(solar_term(2025, 6, 21), Some("夏至"))
  assert_eq(solar_term(2025, 10, 8), Some("寒露"))
  assert_eq(solar_term(2025, 12, 21), Some("冬至"))
  assert_eq(solar_term(2025, 2, 3), Some("立春"))
}

///|
test "anchor: day-boundary sensitive terms" {
  // 2021-02-03 立春 falls at 22:59 Beijing — late in the day; the changeover
  // must still land on 02-03, not 02-04.
  assert_eq(solar_term(2021, 2, 3), Some("立春"))
  assert_eq(solar_term(2021, 2, 4), None)
  // 2023-06-21 夏至 22:58 Beijing.
  assert_eq(solar_term(2023, 6, 21), Some("夏至"))
}

///|
test "anchor: years where cheap approximations break" {
  // 1987 and 2058 are classic off-by-one years for [Y*D+C] formulas.
  assert_eq(solar_term(1987, 3, 21), Some("春分"))
  assert_eq(solar_term(1987, 6, 22), Some("夏至"))
  assert_eq(solar_term(2058, 6, 21), Some("夏至"))
  assert_eq(solar_term(2058, 12, 21), Some("冬至"))
}

///|
test "anchor: early and late range" {
  assert_eq(solar_term(1901, 1, 6), Some("小寒"))
  assert_eq(solar_term(1950, 4, 5), Some("清明"))
  assert_eq(solar_term(2098, 3, 20), Some("春分"))
}

///|
test "non-term day returns None" {
  assert_eq(solar_term(2025, 10, 7), None)
  assert_eq(solar_term(2025, 1, 1), None)
  assert_eq(solar_term(2025, 6, 15), None)
}

///|
test "out of supported range returns None" {
  assert_eq(solar_term(1899, 6, 1), None)
  assert_eq(solar_term(2101, 3, 20), None)
}

///|
test "every year has exactly 24 distinct term days (sampled years)" {
  // Loop invariant: scanning a full year finds exactly 24 changeover days
  // with 24 distinct names. solar_term itself guards the range, so a
  // simple 1..31 scan with per-month day bounds via solar_term's own
  // None result works — day 32+ is simply never a valid date.
  let years = [1905, 1950, 2025, 2077, 2098]
  for y in years {
    let names : Array[String] = []
    for m in 1..<=12 {
      for d in 1..<=31 {
        match solar_term(y, m, d) {
          Some(n) => names.push(n)
          None => ()
        }
      }
    }
    assert_eq(names.length(), 24, msg=y.to_string() + ": expected 24 terms")
    // distinct check
    let seen : Array[String] = []
    for n in names {
      if !seen.contains(n) {
        seen.push(n)
      }
    }
    assert_eq(seen.length(), 24)
  }
}
