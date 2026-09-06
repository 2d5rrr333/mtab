// Widget visibility toggles (configuration capability).

///|
/// Per-widget display switches. The search box is always shown and has no
/// switch here (see configuration spec).
pub(all) struct WidgetsConfig {
  clock : Bool
  bookmarks : Bool
} derive(Eq, Debug)

///|
pub impl ToJson for WidgetsConfig with fn to_json(self) {
  { "clock": self.clock, "bookmarks": self.bookmarks }
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
  }
}
