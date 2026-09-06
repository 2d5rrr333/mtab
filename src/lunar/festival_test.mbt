// Festival anchor tests (solar-terms-festivals task 2.1 / 2.2).

///|
fn festival_of(y : Int, m : Int, d : Int) -> String? {
  match solar_to_lunar(y, m, d) {
    Some(ld) => festival_for(y, m, d, ld)
    None => None
  }
}

///|
test "anchor: 2025 traditional festivals" {
  // 2025: 春节 01-29, 端午 05-31, 七夕 08-29, 中秋 10-06, 重阳 10-29
  assert_eq(festival_of(2025, 1, 29), Some("春节"))
  assert_eq(festival_of(2025, 5, 31), Some("端午节"))
  assert_eq(festival_of(2025, 8, 29), Some("七夕节"))
  assert_eq(festival_of(2025, 10, 6), Some("中秋节"))
  assert_eq(festival_of(2025, 10, 29), Some("重阳节"))
  // 元宵 2025-02-12
  assert_eq(festival_of(2025, 2, 12), Some("元宵节"))
}

///|
test "anchor: statutory gregorian holidays" {
  assert_eq(festival_of(2025, 1, 1), Some("元旦"))
  assert_eq(festival_of(2025, 5, 1), Some("劳动节"))
  assert_eq(festival_of(2025, 10, 1), Some("国庆节"))
}

///|
test "chinese new year's eve (30-day and 29-day final months)" {
  // 2025 除夕 01-28: 腊月廿九 (2024 lunar year ends with a 29-day month)
  assert_eq(festival_of(2025, 1, 28), Some("除夕"))
  // 2024 除夕 02-09: 腊月三十
  assert_eq(festival_of(2024, 2, 9), Some("除夕"))
  // day before a normal month end is NOT 除夕: 2025-10-28 is 腊月... no —
  // it is 九月初八; guard that mid-month days never claim 除夕
  assert_eq(festival_of(2025, 10, 28), None)
}

///|
test "leap-month days never match lunar festivals" {
  // Rule guard: a hypothetical LEAP 五月初五 must not say 端午节 (leap
  // months never re-celebrate). Constructed directly since no leap-first
  // month exists in range.
  let ld = make_lunar(2025, 5, true, 5)
  assert_eq(festival_for(2025, 7, 25, ld), None)
}

///|
fn make_lunar(
  year : Int,
  month : Int,
  is_leap_month : Bool,
  day : Int,
) -> LunarDate {
  { year, month, is_leap_month, day, }
}

///|
test "gregorian holiday wins the priority" {
  // 10-01 is always 国庆节 regardless of lunar date
  let ld = solar_to_lunar(2025, 10, 1).unwrap()
  assert_eq(festival_for(2025, 10, 1, ld), Some("国庆节"))
}

///|
test "ordinary day returns None" {
  assert_eq(festival_of(2025, 10, 8), None) // 寒露 term day but no festival
  assert_eq(festival_of(2025, 6, 15), None)
}
