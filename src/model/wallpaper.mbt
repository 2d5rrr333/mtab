// Wallpaper: one of the built-in assets or a user-uploaded image (configuration capability).

///|
/// The current wallpaper: a built-in asset id, or custom image data
/// (`data:image/...;base64,....`). At most one custom wallpaper exists at a
/// time (design D6).
pub(all) enum Wallpaper {
  Builtin(String)
  Custom(String)
} derive(Eq, Debug)

///|
pub impl ToJson for Wallpaper with fn to_json(self) {
  match self {
    Builtin(id) => { "type": "builtin", "id": id }
    Custom(data) => { "type": "custom", "data": data }
  }
}

///|
pub impl FromJson for Wallpaper with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> Wallpaper raise @json.JsonDecodeError {
  let map = expect_object(json, path)
  match str_field(map, "type", path) {
    "builtin" => Builtin(str_field(map, "id", path))
    "custom" => Custom(str_field(map, "data", path))
    other =>
      raise @json.JsonDecodeError((path, "unknown wallpaper type: " + other))
  }
}
