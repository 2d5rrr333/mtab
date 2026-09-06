// Festivals: PRC public holidays (Gregorian) and Chinese traditional
// festivals (lunar), including Chinese New Year's Eve (solar-terms-festivals
// design D4). O(1) table lookups, no state.

///|
/// PRC statutory holiday names for Gregorian (month, day).
/// 元旦 / 劳动节 / 国庆节 (clock-widget spec: statutory set).
fn solar_festival(m : Int, d : Int) -> String? {
  match (m, d) {
    (1, 1) => Some("元旦")
    (5, 1) => Some("劳动节")
    (10, 1) => Some("国庆节")
    _ => None
  }
}

///|
/// Traditional festival names for lunar (month, day); leap-month days
/// never match (a leap fifth month does not re-celebrate 端午).
fn lunar_festival(month : Int, day : Int, is_leap : Bool) -> String? {
  if is_leap {
    return None
  }
  match (month, day) {
    (1, 1) => Some("春节")
    (1, 15) => Some("元宵节")
    (5, 5) => Some("端午节")
    (7, 7) => Some("七夕节")
    (8, 15) => Some("中秋节")
    (9, 9) => Some("重阳节")
    _ => None
  }
}

///|
/// Chinese New Year's Eve: the last day of the 12th lunar month. Detected
/// as "tomorrow (solar) is lunar 正月初一", which handles both 30-day and
/// 29-day final months without table lookups.
fn is_chinese_new_years_eve(
  y : Int,
  m : Int,
  d : Int,
  lunar : LunarDate,
) -> Bool {
  if lunar.is_leap_month || lunar.month != 12 {
    return false
  }
  // last day of the month: tomorrow's lunar date is 正月初一 of next year
  let tomorrow = next_day(y, m, d)
  let (ny, nm, nd) = tomorrow
  match solar_to_lunar(ny, nm, nd) {
    Some(next) => !next.is_leap_month && next.month == 1 && next.day == 1
    None => false
  }
}

///|
/// The festival name for Gregorian y-m-d, given its already-converted
/// lunar date. Priority: Gregorian statutory > lunar traditional > 除夕.
/// None when the day is no festival. Pure function.
pub fn festival_for(y : Int, m : Int, d : Int, lunar : LunarDate) -> String? {
  match solar_festival(m, d) {
    Some(name) => Some(name)
    None =>
      match lunar_festival(lunar.month, lunar.day, lunar.is_leap_month) {
        Some(name) => Some(name)
        None =>
          if is_chinese_new_years_eve(y, m, d, lunar) {
            Some("除夕")
          } else {
            None
          }
      }
  }
}
