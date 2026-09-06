// Search: engine list and the user's current engine choice (search-box capability).

///|
/// A search engine; `url_template` contains a `{query}` placeholder.
pub(all) struct Engine {
  id : String
  name : String
  url_template : String
} derive(Eq, Debug)

///|
/// The engine list plus the currently selected engine id.
pub(all) struct SearchConfig {
  engines : Array[Engine]
  current : String
} derive(Eq, Debug)

///|
pub impl ToJson for Engine with fn to_json(self) {
  { "id": self.id, "name": self.name, "urlTemplate": self.url_template }
}

///|
pub impl FromJson for Engine with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> Engine raise @json.JsonDecodeError {
  let map = expect_object(json, path)
  {
    id: str_field(map, "id", path),
    name: str_field(map, "name", path),
    url_template: str_field(map, "urlTemplate", path),
  }
}

///|
pub impl ToJson for SearchConfig with fn to_json(self) {
  { "engines": self.engines, "current": self.current }
}

///|
pub impl FromJson for SearchConfig with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> SearchConfig raise @json.JsonDecodeError {
  let map = expect_object(json, path)
  let engines : Array[Engine] = []
  for i, item in array_field(map, "engines", path) {
    engines.push(@json.from_json(item, path=path.add_index(i)))
  }
  { engines, current: str_field(map, "current", path) }
}
