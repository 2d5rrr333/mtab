// Widget visibility toggles (configuration capability).

///|
/// Per-widget display switches. The search box is always shown and has no
/// switch here (see configuration spec). Countdown ships off by default
/// (countdown-widget design D5).
pub(all) struct WidgetsConfig {
  clock : Bool
  bookmarks : Bool
  countdown : Bool
} derive(Eq, Debug)

///|
pub impl ToJson for WidgetsConfig with fn to_json(self) {
  {
    "clock": self.clock,
    "bookmarks": self.bookmarks,
    "countdown": self.countdown,
  }
}

///|
pub impl FromJson for WidgetsConfig with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> WidgetsConfig raise @json.JsonDecodeError {
  let map = expect_object(json, path)
  {
    clock: bool_field(map, "clock", path),
    bookmarks: bool_field(map, "bookmarks", path),
    // old files carry no countdown switch: default off
    countdown: countdown_field_opt(map),
  }
}

///|
/// Optional countdown switch: absent -> false; present but non-boolean
/// also falls back to false (bool_field_opt semantics).
fn countdown_field_opt(map : Map[String, Json]) -> Bool {
  match map.get("countdown") {
    Some(True) => true
    _ => false
  }
}
