// Bookmark: one saved site in the grid (bookmark-grid capability).

///|
/// A saved site shown in the bookmark grid.
pub(all) struct Bookmark {
  id : String
  name : String
  url : String
} derive(Eq, Debug)

///|
pub impl ToJson for Bookmark with fn to_json(self) {
  { "id": self.id, "name": self.name, "url": self.url }
}

///|
pub impl FromJson for Bookmark with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> Bookmark raise @json.JsonDecodeError {
  let map = expect_object(json, path)
  {
    id: str_field(map, "id", path),
    name: str_field(map, "name", path),
    url: str_field(map, "url", path),
  }
}
