// Config: the whole persisted state, schema version 1 (design D6).
// One JSON shape serves bridge, localStorage, and export file.

///|
/// Current config schema version understood by this build.
pub const CONFIG_VERSION : Int = 1

///|
/// The complete persisted configuration.
pub(all) struct Config {
  version : Int
  bookmarks : Array[Bookmark]
  search : SearchConfig
  widgets : WidgetsConfig
  wallpaper : Wallpaper
} derive(Eq, Debug)

///|
pub impl ToJson for Config with fn to_json(self) {
  {
    "version": self.version,
    "bookmarks": self.bookmarks,
    "search": self.search,
    "widgets": self.widgets,
    "wallpaper": self.wallpaper,
  }
}

///|
pub impl FromJson for Config with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> Config raise @json.JsonDecodeError {
  let map = expect_object(json, path)
  let bookmarks : Array[Bookmark] = []
  for i, item in array_field(map, "bookmarks", path) {
    bookmarks.push(@json.from_json(item, path=path.add_index(i)))
  }
  {
    version: int_field(map, "version", path),
    bookmarks,
    search: @json.from_json(field(map, "search", path)),
    widgets: @json.from_json(field(map, "widgets", path)),
    wallpaper: @json.from_json(field(map, "wallpaper", path)),
  }
}

///|
/// The default configuration: preset engines (baidu/google/bing), empty
/// bookmark grid, all widgets on, first built-in wallpaper.
pub fn Config::default() -> Config {
  {
    version: CONFIG_VERSION,
    bookmarks: [],
    search: {
      engines: [
        {
          id: "baidu",
          name: "百度",
          url_template: "https://www.baidu.com/s?wd={query}",
        },
        {
          id: "google",
          name: "Google",
          url_template: "https://www.google.com/search?q={query}",
        },
        {
          id: "bing",
          name: "Bing",
          url_template: "https://www.bing.com/search?q={query}",
        },
      ],
      current: "baidu",
    },
    widgets: { clock: true, bookmarks: true },
    wallpaper: Builtin("w1"),
  }
}

///|
/// Decode a stored/imported config from its JSON text form.
/// Raises on invalid JSON or wrong structure; version is decoded but not
/// checked here (see store's config_import).
pub fn Config::decode(text : String) -> Config raise {
  @json.from_json(@json.parse(text))
}

///|
/// Encode this config to its JSON text form (persistence + export shape).
pub fn Config::encode(self : Config) -> String {
  ToJson::to_json(self).stringify()
}
