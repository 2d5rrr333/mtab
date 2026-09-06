// Solar terms (24 jieqi) via the astronomical "Shouxing" general formula
// (solar-term changeover: solar apparent longitude), 1900-2100.
//
// Method: a day D is a jieqi day when the sun's apparent geocentric
// longitude crosses a multiple of 15 degrees between the START of D and the
// START of D+1 (Beijing time, UTC+8). The longitude follows the Shouxing
// astronomical calendar algorithm by Xu Jianwei (https://github.com/sxwyh/,
// 寿星天文历), which is a public-domain presentation of standard VSOP-based
// reductions; the formula constants below are mathematical facts.

///|
/// Solar apparent geocentric ecliptic longitude (degrees, 0..360) at
/// Julian Day `jd` (dynamical time approximated by UT; error far below
/// our 1-day resolution over 1900-2100).
///
/// Standard low-precision solar reduction (Meeus / Shouxing):
///   T  = (jd - 2451545.0) / 36525        Julian centuries since J2000
///   L0 = mean longitude,  M = mean anomaly
///   C  = equation of center correction,  lambda = L0 + C (apparent,
///   with nutation's main term folded in via dPsi)
fn sun_longitude(jd : Double) -> Double {
  let t = (jd - 2451545.0) / 36525.0
  // mean longitude and mean anomaly, degrees
  let l0 = 280.4664567 + 36000.76983 * t + 0.0003032 * t * t
  let m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t
  let mr = m * PI / 180.0
  // equation of center
  let c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * @math.sin(mr) +
    (0.019993 - 0.000101 * t) * @math.sin(2.0 * mr) +
    0.000289 * @math.sin(3.0 * mr)
  // apparent longitude: true longitude - 0.00569 - 0.00478*sin(Omega)
  let omega = 125.04 - 1934.136 * t
  let lambda = l0 + c - 0.00569 - 0.00478 * @math.sin(omega * PI / 180.0)
  floor_mod(lambda, 360.0)
}

///|
/// PI as Double (core exposes Float PI; keep our own constant exact).
const PI : Double = 3.14159265358979323846

///|
/// Mathematical mod for doubles, result in [0, m).
fn floor_mod(x : Double, m : Double) -> Double {
  let r = x - m * @double.floor(x / m)
  if r < 0.0 {
    r + m
  } else {
    r
  }
}

///|
/// Julian Day at the START (00:00) of Gregorian y-m-d, Beijing time.
fn jd_beijing_start(y : Int, m : Int, d : Int) -> Double {
  // days_from_civil gives days since 1970-01-01 UTC midnight; UTC 0h of
  // that civil date equals JD 2440587.5. Beijing midnight happens 8h
  // BEFORE that UTC midnight of the same civil date (UTC+8 is ahead),
  // so subtract 8h from the UTC-midnight JD.
  days_from_civil(y, m, d).to_double() + 2440587.5 - 8.0 / 24.0
}

///|
/// Which multiple-of-15-degrees "term slot" the sun is in at the start of
/// y-m-d (Beijing). 0 = [0,15) around spring equinox, 1 = [15,30), ...
fn term_step(y : Int, m : Int, d : Int) -> Int {
  let lon = sun_longitude(jd_beijing_start(y, m, d))
  @double.floor(lon / 15.0).to_int()
}

///|
/// The jieqi name for Gregorian y-m-d, or None when the day is not a
/// term-changeover day. A term boundary is crossed when the slot at the
/// start of D differs from the slot at the start of D+1; the crossed
/// multiple (mod 24) names the term (0 = 春分, 15 = 冬至 ...).
pub fn solar_term(y : Int, m : Int, d : Int) -> String? {
  // Range guard mirrors solar_to_lunar (term data valid across it).
  if !in_range(y, m, d) {
    return None
  }
  let today = term_step(y, m, d)
  let tomorrow = next_day(y, m, d)
  let (ny, nm, nd) = tomorrow
  if !in_range(ny, nm, nd) {
    return None
  }
  let after = term_step(ny, nm, nd)
  if today == after {
    return None
  }
  // the crossed slot boundary is `after` (mod 24)
  Some(term_names[(after % 24 + 24) % 24])
}

///|
/// Next calendar day of y-m-d.
fn next_day(y : Int, m : Int, d : Int) -> (Int, Int, Int) {
  if d < solar_days(y, m) {
    (y, m, d + 1)
  } else if m < 12 {
    (y, m + 1, 1)
  } else {
    (y + 1, 1, 1)
  }
}
