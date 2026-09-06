// Gregorian -> Chinese lunar calendar conversion, 1900-2100 (design D7).
//
// Algorithm ported from solarlunar 3.1.0 (https://github.com/yize/solarlunar,
// MIT), originally Ajing's calendar.js. Unlike the original, the ganzhi year
// name follows the lunar year number (switching at lunar new year), matching
// the common almanac display convention used by the clock-widget spec.

///|
/// A lunar date. `month` is 1..12; `is_leap_month` marks the leap month
/// of the year. Supported solar range: 1900-01-31 .. 2100-12-31.
pub(all) struct LunarDate {
  year : Int
  month : Int
  is_leap_month : Bool
  day : Int
} derive(Eq, Debug)

///|
fn info_of(lunar_year : Int) -> Int {
  lunar_info[lunar_year - 1900]
}

///|
/// Total days in lunar `year` (353..385).
fn lunar_year_days(year : Int) -> Int {
  let info = info_of(year)
  let mut sum = 348
  let mut bit = 0x8000
  while bit >= 0x10 {
    if (info & bit) != 0 {
      sum = sum + 1
    }
    bit = bit / 2
  }
  sum + leap_days(year)
}

///|
/// The leap month number of lunar `year`, or 0 when there is none.
fn leap_month(year : Int) -> Int {
  info_of(year) & 0xf
}

///|
/// Days in the leap month of lunar `year`, or 0 when there is none.
fn leap_days(year : Int) -> Int {
  if leap_month(year) != 0 {
    if (info_of(year) & 0x10000) != 0 {
      30
    } else {
      29
    }
  } else {
    0
  }
}

///|
/// Days in regular month `month` (1..12) of lunar `year`.
fn month_days(year : Int, month : Int) -> Int {
  if (info_of(year) & (0x10000 >> month)) != 0 {
    30
  } else {
    29
  }
}

///|
/// Days in Gregorian month `m` (1..12) of year `y`.
fn solar_days(y : Int, m : Int) -> Int {
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

///|
/// Days since 1970-01-01 of a Gregorian date (Howard Hinnant's
/// days_from_civil). Valid for our 1900+ range.
fn days_from_civil(y : Int, m : Int, d : Int) -> Int {
  let yy = if m <= 2 { y - 1 } else { y }
  let era = yy / 400
  let yoe = yy - era * 400
  let mp = (m + 9) % 12
  let doy = (153 * mp + 2) / 5 + d - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468
}

///|
/// Whether a Gregorian date is within the supported table range.
fn in_range(y : Int, m : Int, d : Int) -> Bool {
  if y < 1900 || y > 2100 || m < 1 || m > 12 {
    return false
  }
  if y == 1900 && (m < 1 || (m == 1 && d < 31)) {
    return false
  }
  d >= 1 && d <= solar_days(y, m)
}

///|
/// Convert a Gregorian date to its lunar date. Returns None outside the
/// supported range 1900-01-31 .. 2100-12-31.
pub fn solar_to_lunar(y : Int, m : Int, d : Int) -> LunarDate? {
  if !in_range(y, m, d) {
    return None
  }
  // offset = days after lunar 1900-01-01 (which is Gregorian 1900-01-31).
  let mut offset = days_from_civil(y, m, d) - days_from_civil(1900, 1, 31)
  // Find the lunar year: subtract whole lunar years while offset stays
  // positive (classic scan from solarlunar).
  let mut i = 1900
  let mut temp = 0
  while i < 2101 && offset > 0 {
    temp = lunar_year_days(i)
    offset = offset - temp
    i = i + 1
  }
  if offset < 0 {
    offset = offset + temp
    i = i - 1
  }
  let year = i
  // Walk lunar months, inserting the leap month at its position.
  let lm = leap_month(year)
  let mut is_leap = false
  let mut j = 1
  temp = 0
  while j < 13 && offset > 0 {
    if lm > 0 && j == lm + 1 && !is_leap {
      // Enter the leap month: re-run this month index in leap mode.
      j = j - 1
      is_leap = true
      temp = leap_days(year)
    } else {
      temp = month_days(year, j)
    }
    if is_leap && j == lm + 1 {
      is_leap = false
    }
    offset = offset - temp
    j = j + 1
  }
  if offset == 0 && lm > 0 && j == lm + 1 {
    if is_leap {
      is_leap = false
    } else {
      is_leap = true
      j = j - 1
    }
  }
  if offset < 0 {
    offset = offset + temp
    j = j - 1
  }
  Some({ year, month: j, is_leap_month: is_leap, day: offset + 1 })
}

///|
/// Weekday name ("星期一".."星期日") for a Gregorian date.
pub fn weekday_name(y : Int, m : Int, d : Int) -> String {
  // 1970-01-01 was a Thursday: index 4 with 0 = Sunday. Floor-mod keeps the
  // index non-negative for dates before the epoch (1900+ is negative there).
  let days = days_from_civil(y, m, d)
  let w = (days % 7 + 7 + 4) % 7
  let names : Array[String] = ["日", "一", "二", "三", "四", "五", "六"]
  "星期" + names[w]
}

///|
/// Ganzhi year name such as "乙巳年", following the lunar year number.
pub fn LunarDate::year_ganzhi(self : LunarDate) -> String {
  let offset = self.year - 4
  gan[offset % 10] + zhi[offset % 12] + "年"
}

///|
/// Zodiac animal of the lunar year, such as "蛇".
pub fn LunarDate::zodiac(self : LunarDate) -> String {
  animals[(self.year - 4) % 12]
}

///|
/// Lunar month display name, with the leap prefix when applicable
/// ("正月", "闰六月").
pub fn LunarDate::month_name(self : LunarDate) -> String {
  let base = month_names[self.month - 1] + "月"
  if self.is_leap_month {
    "闰" + base
  } else {
    base
  }
}

///|
/// Lunar day display name ("初一".."三十").
pub fn LunarDate::day_name(self : LunarDate) -> String {
  let d = self.day
  if d == 10 {
    "初十"
  } else if d == 20 {
    "二十"
  } else if d == 30 {
    "三十"
  } else {
    day_prefixes[d / 10] + digits[d % 10 - 1]
  }
}

///|
/// Full display string such as "乙巳年正月初一".
pub fn LunarDate::to_display(self : LunarDate) -> String {
  self.year_ganzhi() + self.month_name() + self.day_name()
}
