// Store: the state tree and the pure update function (design D1/D2/D4).

///|
/// Clock display info derived from the current date (design D4): the JS
/// side ticks seconds locally; weekday and lunar text come from here.
pub(all) struct ClockView {
  weekday : String
  lunar : String?
} derive(Eq, Debug, ToJson)

///|
/// Full state exposed over the bridge: the config plus the derived clock.
pub(all) struct Store {
  config : @model.Config
  clock : ClockView?
} derive(Eq, Debug, ToJson)

///|
/// The dispatch response envelope: full state + effects.
pub(all) struct Response {
  state : Store
  effects : Array[Effect]
} derive(Eq, Debug, ToJson)

///|
/// Initialize the store from a stored config (None or undecodable text falls
/// back to the default config) and today's date ("YYYY-MM-DD").
/// (Not named `init`: that is reserved for the wasm start function.)
pub fn open(stored : String?, today : String) -> Response {
  let config : @model.Config = match stored {
    Some(text) =>
      @model.Config::decode(text) catch {
        _ => @model.Config::default()
      }
    None => @model.Config::default()
  }
  respond({ config, clock: clock_view_for(today), }, [])
}

///|
/// Apply one event; returns the next full state plus effects for the shell.
pub fn update(store : Store, event : Event) -> Response {
  let (next, effects) = handle(store, event)
  { state: next, effects, }
}

///|
fn respond(state : Store, effects : Array[Effect]) -> Response {
  { state, effects, }
}

///|
fn handle(store : Store, event : Event) -> (Store, Array[Effect]) {
  match event {
    BookmarkAdd(name~, url~) =>
      match @model.normalize_url(url) {
        None =>
          (store, [NotifyError(message="网址无效，请检查后重试")])
        Some(u) => {
          let id = next_bookmark_id(store.config.bookmarks)
          let trimmed = name.trim().to_owned()
          let display_name = if trimmed == "" { u } else { trimmed }
          let bookmark : @model.Bookmark = { id, name: display_name, url: u, }
          let bookmarks = store.config.bookmarks.copy()
          bookmarks.push(bookmark)
          ({ ..store, config: { ..store.config, bookmarks, }, }, [Save])
        }
      }
    BookmarkEdit(id~, name~, url~) =>
      match @model.normalize_url(url) {
        None =>
          (store, [NotifyError(message="网址无效，请检查后重试")])
        Some(u) => {
          let trimmed = name.trim().to_owned()
          let display_name = if trimmed == "" { u } else { trimmed }
          let bookmarks = store.config.bookmarks.copy()
          let mut edited = false
          for i, b in bookmarks {
            if b.id == id {
              bookmarks[i] = { id: b.id, name: display_name, url: u, }
              edited = true
            }
          }
          if edited {
            ({ ..store, config: { ..store.config, bookmarks, }, }, [Save])
          } else {
            (store, [NotifyError(message="要编辑的书签不存在")])
          }
        }
      }
    BookmarkDelete(id~) => {
      let remaining = store.config.bookmarks.filter(b => b.id != id)
      if remaining.length() != store.config.bookmarks.length() {
        (
          { ..store, config: { ..store.config, bookmarks: remaining, }, },
          [Save],
        )
      } else {
        (store, [])
      }
    }
    EngineSelect(id~) =>
      if store.config.search.engines.any(e => e.id == id) {
        (
          {
            ..store,
            config: {
              ..store.config,
              search: { ..store.config.search, current: id, },
            },
          },
          [Save],
        )
      } else {
        (store, [NotifyError(message="未知的搜索引擎")])
      }
    SearchSubmit(query~) => {
      let q = query.trim().to_owned()
      if q == "" {
        // search-box spec: empty keyword must not navigate.
        (store, [])
      } else {
        let current = store.config.search.current
        let mut found : @model.Engine? = None
        for e in store.config.search.engines {
          if e.id == current {
            found = Some(e)
          }
        }
        match found {
          Some(engine) =>
            (store, [OpenUrl(url=build_search_url(engine.url_template, q))])
          None => (store, [NotifyError(message="未找到当前搜索引擎")])
        }
      }
    }
    WidgetToggle(widget~) => {
      let widgets = store.config.widgets
      match widget {
        "clock" =>
          (
            {
              ..store,
              config: {
                ..store.config,
                widgets: { ..widgets, clock: !widgets.clock, },
              },
            },
            [Save],
          )
        "bookmarks" =>
          (
            {
              ..store,
              config: {
                ..store.config,
                widgets: { ..widgets, bookmarks: !widgets.bookmarks, },
              },
            },
            [Save],
          )
        _ => (store, [])
      }
    }
    WallpaperSetBuiltin(id~) =>
      (
        {
          ..store,
          config: { ..store.config, wallpaper: @model.Wallpaper::Builtin(id), },
        },
        [Save],
      )
    WallpaperSetCustom(data~) =>
      (
        {
          ..store,
          config: { ..store.config, wallpaper: @model.Wallpaper::Custom(data), },
        },
        [Save],
      )
    ConfigImport(json~) =>
      try {
        let cfg = @model.Config::decode(json)
        if cfg.version == @model.CONFIG_VERSION {
          ({ config: cfg, clock: store.clock, }, [Save])
        } else {
          (
            store,
            [NotifyError(message="导入失败：不支持的配置版本")],
          )
        }
      } catch {
        _ => (store, [NotifyError(message="导入失败：文件格式无效")])
      }
    TickDate(date~) => ({ ..store, clock: clock_view_for(date), }, [])
  }
}

///|
/// Generate a fresh bookmark id ("b" + next number above all existing ones).
fn next_bookmark_id(bookmarks : Array[@model.Bookmark]) -> String {
  let mut max = 0
  for b in bookmarks {
    let n = numeric_suffix(b.id)
    if n > max {
      max = n
    }
  }
  "b" + (max + 1).to_string()
}

///|
/// Parse the numeric suffix of a "bN" id ("b12" -> 12). Non-digit prefixes
/// such as "b" are skipped; a string with digits followed by junk yields 0.
fn numeric_suffix(s : String) -> Int {
  let mut n = 0
  let mut started = false
  for c in s {
    if c < '0' || c > '9' {
      if started {
        return 0
      }
      continue
    }
    started = true
    n = n * 10 + (c.to_int() - '0'.to_int())
  }
  n
}

///|
/// Parse "YYYY-MM-DD" into (year, month, day).
fn parse_ymd(s : String) -> (Int, Int, Int)? {
  let parts : Array[String] = []
  for p in s.split("-") {
    parts.push(p.to_owned())
  }
  if parts.length() != 3 {
    return None
  }
  match
    (parse_digits(parts[0]), parse_digits(parts[1]), parse_digits(parts[2])) {
    (Some(y), Some(m), Some(d)) =>
      if m >= 1 && m <= 12 && d >= 1 && d <= 31 {
        Some((y, m, d))
      } else {
        None
      }
    _ => None
  }
}

///|
fn parse_digits(s : String) -> Int? {
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
/// Clock view for a date string: weekday always, lunar text when within the
/// supported range (clock-widget spec: out of range shows no lunar info).
fn clock_view_for(date : String) -> ClockView? {
  match parse_ymd(date) {
    Some((y, m, d)) => {
      let lunar = match @lunar.solar_to_lunar(y, m, d) {
        Some(ld) => Some(ld.to_display())
        None => None
      }
      Some({ weekday: @lunar.weekday_name(y, m, d), lunar, })
    }
    None => None
  }
}
