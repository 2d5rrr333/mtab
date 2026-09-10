// Countdown entries (countdown-widget capability): a name plus a target
// Gregorian date, persisted inside the config.

///|
/// One countdown entry. `date` is "YYYY-MM-DD"; `id` follows the "cN"
/// pattern like bookmark/group ids.
pub(all) struct Countdown {
  id : String
  name : String
  date : String
} derive(Eq, Debug)

///|
pub impl ToJson for Countdown with fn to_json(self) {
  { "id": self.id, "name": self.name, "date": self.date }
}

///|
pub impl FromJson for Countdown with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> Countdown raise @json.JsonDecodeError {
  let map = expect_object(json, path)
  {
    id: str_field(map, "id", path),
    name: str_field(map, "name", path),
    date: str_field(map, "date", path),
  }
}

///|
/// Parse "YYYY-MM-DD" into (year, month, day); None when the shape is
/// wrong or the date is not a real calendar date (e.g. 2026-02-30).
pub fn parse_countdown_date(s : String) -> (Int, Int, Int)? {
  let parts : Array[String] = []
  for p in s.split("-") {
    parts.push(p.to_owned())
  }
  if parts.length() != 3 {
    return None
  }
  let y = all_digits(parts[0])
  let m = all_digits(parts[1])
  let d = all_digits(parts[2])
  match (y, m, d) {
    (Some(y), Some(m), Some(d)) =>
      if y < 1900 || y > 2100 || m < 1 || m > 12 || d < 1 {
        None
      } else if d > @lunar.solar_days(y, m) {
        None
      } else {
        Some((y, m, d))
      }
    _ => None
  }
}

///|
/// Pure digits string to Int (None when empty or non-digit). Unlike
/// store's parse_digits this rejects the empty string outright.
fn all_digits(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  let mut n = 0
  for c in s {
    if c < '0' || c > '9' {
      return None
    }
    n = n * 10 + (c.to_int() - '0'.to_int())
  }
  Some(n)
}

///|
/// Whether a countdown date string is a valid target date.
pub fn validate_countdown_date(s : String) -> Bool {
  parse_countdown_date(s) is Some(_)
}

///|
/// Signed day difference between a target date and `today`
/// ("YYYY-MM-DD"): positive = N days remain, 0 = is today,
/// negative = N days past.
pub fn remaining_days(date : String, today : String) -> Int? {
  match (parse_countdown_date(date), parse_countdown_date(today)) {
    (Some((ty, tm, td)), Some((ny, nm, nd))) =>
      Some(
        @lunar.gregorian_day_number(ty, tm, td) -
        @lunar.gregorian_day_number(ny, nm, nd),
      )
    _ => None
  }
}
