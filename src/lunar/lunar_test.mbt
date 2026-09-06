// Golden tests for the lunar conversion (task 3.1, clock-widget spec).

///|
test "2025-01-29 is 乙巳年正月初一" {
  let lunar = solar_to_lunar(2025, 1, 29)
  assert_true(
    lunar is Some({ year: 2025, month: 1, is_leap_month: false, day: 1 }),
  )
  assert_eq(lunar.unwrap().to_display(), "乙巳年正月初一")
  assert_eq(lunar.unwrap().zodiac(), "蛇")
}

///|
test "2025 leap month six is marked" {
  // 2025-07-25 is 闰六月初一.
  let lunar = solar_to_lunar(2025, 7, 25)
  assert_true(
    lunar is Some({ year: 2025, month: 6, is_leap_month: true, day: 1 }),
  )
  assert_eq(lunar.unwrap().month_name(), "闰六月")
  // Day after the leap month ends is still a normal date (2025-08-23).
  let after = solar_to_lunar(2025, 8, 23)
  assert_true(after is Some({ year: 2025, month: 7, .. }))
}

///|
test "boundary dates" {
  // First supported day: lunar 1900-01-01.
  let first = solar_to_lunar(1900, 1, 31)
  assert_true(first is Some({ year: 1900, month: 1, day: 1, .. }))
  assert_eq(first.unwrap().year_ganzhi(), "庚子年")
  // Day before the range: rejected.
  assert_true(solar_to_lunar(1900, 1, 30) is None)
  assert_true(solar_to_lunar(1899, 12, 31) is None)
  // Last supported day and just beyond.
  assert_true(solar_to_lunar(2100, 12, 31) is Some(_))
  assert_true(solar_to_lunar(2101, 1, 1) is None)
}

///|
test "known spring festivals" {
  // 2024-02-10: 甲辰年正月初一.
  let y2024 = solar_to_lunar(2024, 2, 10)
  assert_eq(y2024.unwrap().to_display(), "甲辰年正月初一")
  // 2023-01-22: 癸卯年正月初一.
  let y2023 = solar_to_lunar(2023, 1, 22)
  assert_eq(y2023.unwrap().to_display(), "癸卯年正月初一")
}

///|
test "day names" {
  assert_eq(solar_to_lunar(2025, 1, 29).unwrap().day_name(), "初一")
  assert_eq(solar_to_lunar(2025, 2, 7).unwrap().day_name(), "初十")
  assert_eq(solar_to_lunar(2025, 2, 17).unwrap().day_name(), "二十")
  assert_eq(solar_to_lunar(2025, 2, 18).unwrap().day_name(), "廿一")
  assert_eq(solar_to_lunar(2025, 2, 26).unwrap().day_name(), "廿九")
}

///|
test "weekday names" {
  assert_eq(weekday_name(2025, 1, 29), "星期三")
  assert_eq(weekday_name(2024, 2, 10), "星期六")
  assert_eq(weekday_name(1900, 1, 31), "星期三")
  assert_eq(weekday_name(2000, 1, 1), "星期六")
}

///|
test "consecutive days are self-consistent over 2025 (leap year 6th month)" {
  // Local Gregorian month length (the package one is private).
  fn month_len(y : Int, m : Int) -> Int {
    if m == 2 {
      if (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 {
        29
      } else {
        28
      }
    } else if m == 4 || m == 6 || m == 9 || m == 11 {
      30
    } else {
      31
    }
  }
  // Walk the whole Gregorian year: each next lunar date must be day+1 in the
  // same (month, leap) mode, or day 1 with month advanced (leap transitions
  // included).
  let mut y = 2025
  let mut m = 1
  let mut d = 1
  let mut prev = solar_to_lunar(y, m, d).unwrap()
  for ;; {
    // Advance one Gregorian day.
    d = d + 1
    if d > month_len(y, m) {
      d = 1
      m = m + 1
      if m > 12 {
        m = 1
        y = y + 1
      }
    }
    if y > 2025 {
      break
    }
    let cur = solar_to_lunar(y, m, d).unwrap()
    let ok = if cur.year == prev.year &&
      cur.month == prev.month &&
      cur.is_leap_month == prev.is_leap_month {
      cur.day == prev.day + 1
    } else {
      cur.day == 1
    }
    if !ok {
      fail(
        "inconsistent transition \{y}-\{m}-\{d}: \{prev.to_display()} -> \{cur.to_display()}",
      )
    }
    prev = cur
  }
}
