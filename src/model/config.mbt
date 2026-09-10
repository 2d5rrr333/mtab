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
  wallpaper_blur : Int
  theme : String
  countdowns : Array[Countdown]
} derive(Eq, Debug)

///|
/// Upper bound for wallpaper blur in px (group-collapse-blur D2).
pub const WALLPAPER_BLUR_MAX : Int = 20

///|
pub impl ToJson for Config with fn to_json(self) {
  {
    "version": CONFIG_VERSION,
    "groups": self.groups,
    "search": self.search,
    "widgets": self.widgets,
    "wallpaper": self.wallpaper,
    "wallpaperBlur": self.wallpaper_blur,
    "theme": self.theme,
    "countdowns": self.countdowns,
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
    // old files carry no blur amount: default 0
    wallpaper_blur: int_field_opt(map, "wallpaperBlur"),
    // old files carry no theme: default dark (theme-system D2)
    theme: theme_field(map),
    // old files carry no countdowns: default empty list (countdown-widget D1)
    countdowns: countdowns_field(map, path),
  }
}

///|
/// Theme field: "dark" | "light" | "auto"; absent/invalid -> "dark".
fn theme_field(map : Map[String, Json]) -> String {
  match map.get("theme") {
    Some(String("light")) => "light"
    Some(String("auto")) => "auto"
    _ => "dark"
  }
}

///|
/// Countdowns field: absent or non-array -> empty list (countdown-widget
/// design D1 backward compatibility). Undecodable entries are skipped so
/// one bad row never breaks the whole config.
fn countdowns_field(
  map : Map[String, Json],
  path : @json.JsonPath,
) -> Array[Countdown] {
  match map.get("countdowns") {
    Some(Array(items)) => {
      let out : Array[Countdown] = []
      for i, item in items {
        out.push(@json.from_json(item, path=path.add_index(i))) catch {
          _ => ()
        }
      }
      out
    }
    _ => []
  }
}

///|
/// The default configuration: preset engines (baidu/google/bing), a default
/// group carrying the starter bookmarks, all primary widgets on, first
/// built-in wallpaper.
pub fn Config::default() -> Config {
  {
    version: CONFIG_VERSION,
    groups: [make_default_group(starter_bookmarks())],
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
    widgets: { clock: true, bookmarks: true, countdown: false, },
    wallpaper: Builtin("w3"),
    wallpaper_blur: 0,
    theme: "dark",
    countdowns: [],
  }
}

///|
/// Starter bookmarks shipped in the default group on first run
/// (starter-presets-and-clock D1). Users can edit/delete them like any
/// other bookmark; once a config is stored they are never re-injected.
pub fn starter_bookmarks() -> Array[Bookmark] {
  [
    { id: "b1", name: "百度", url: "https://www.baidu.com", },
    { id: "b2", name: "哔哩哔哩", url: "https://www.bilibili.com", },
    { id: "b3", name: "知乎", url: "https://www.zhihu.com", },
    { id: "b4", name: "GitHub", url: "https://github.com", },
    { id: "b5", name: "淘宝", url: "https://www.taobao.com", },
    { id: "b6", name: "网易云音乐", url: "https://music.163.com", },
  ]
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
