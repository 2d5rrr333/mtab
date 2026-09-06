// Config: the whole persisted state, schema version 2 (bookmark-groups D1).
// One JSON shape serves bridge, localStorage, and export file.
// Version 1 (flat `bookmarks`) is still DECODED and migrated: the flat
// list lands in the default group, in order.

///|
/// Current config schema version understood by this build (writes v2).
pub const CONFIG_VERSION : Int = 2

///|
/// The complete persisted configuration.
pub(all) struct Config {
  version : Int
  groups : Array[Group]
  search : SearchConfig
  widgets : WidgetsConfig
  wallpaper : Wallpaper
} derive(Eq, Debug)

///|
pub impl ToJson for Config with fn to_json(self) {
  {
    "version": CONFIG_VERSION,
    "groups": self.groups,
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
  let version = int_field(map, "version", path)
  let groups : Array[Group] = match version {
    1 => {
      // v1: flat bookmarks array -> default group, order preserved
      let bookmarks : Array[Bookmark] = []
      match map.get("bookmarks") {
        Some(Array(items)) =>
          for i, item in items {
            bookmarks.push(@json.from_json(item, path=path.add_index(i)))
          }
        _ => ()
      }
      [make_default_group(bookmarks)]
    }
    2 => {
      let groups : Array[Group] = []
      for i, item in array_field(map, "groups", path) {
        groups.push(@json.from_json(item, path=path.add_index(i)))
      }
      ensure_groups_valid(groups)
    }
    other =>
      raise @json.JsonDecodeError(
        (path, "unsupported config version: " + other.to_string()),
      )
  }
  {
    version,
    groups,
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
    groups: [make_default_group([])],
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
      history: [],
    },
    widgets: { clock: true, bookmarks: true, },
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
