// Store: the state tree and the pure update function (design D1/D2/D4).

///|
/// Clock display info derived from the current date (design D4): the JS
/// side ticks seconds locally; weekday and lunar text come from here.
/// solar_term / festival: the jieqi name when the day is a term-changeover
/// day, and the festival name (festival wins the display slot).
pub(all) struct ClockView {
  weekday : String
  lunar : String?
  solar_term : String?
  festival : String?
} derive(Eq, Debug, ToJson)

///|
/// Full state exposed over the bridge: the config, the derived clock, and
/// the transient search suggestions (never persisted; recomputed on
/// history-relevant events, carried along otherwise).
pub(all) struct Store {
  config : @model.Config
  clock : ClockView?
  suggestions : Array[@model.HistoryEntry]
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
  respond(
    {
      config,
      clock: clock_view_for(today),
      suggestions: recent_suggestions(config.search.history),
    },
    [],
  )
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
    BookmarkAdd(name~, url~, group~) =>
      match @model.normalize_url(url) {
        None =>
          (store, [NotifyError(message="网址无效，请检查后重试")])
        Some(u) => {
          let target = match group {
            Some(gid) => gid
            None => @model.DEFAULT_GROUP_ID
          }
          if !group_exists(store.config.groups, target) {
            (store, [NotifyError(message="目标分组不存在")])
          } else {
            let id = next_bookmark_id(store.config.groups)
            let trimmed = name.trim().to_owned()
            let display_name = if trimmed == "" { u } else { trimmed }
            let bookmark : @model.Bookmark = { id, name: display_name, url: u, }
            let groups = map_groups(store.config.groups, target, g => {
              let bookmarks = g.bookmarks.copy()
              bookmarks.push(bookmark)
              { ..g, bookmarks, }
            })
            ({ ..store, config: { ..store.config, groups, }, }, [Save])
          }
        }
      }
    BookmarkEdit(id~, name~, url~, group~) =>
      match @model.normalize_url(url) {
        None =>
          (store, [NotifyError(message="网址无效，请检查后重试")])
        Some(u) => {
          let trimmed = name.trim().to_owned()
          let display_name = if trimmed == "" { u } else { trimmed }
          // optional group move rides along with the edit
          match group {
            Some(gid) if !group_exists(store.config.groups, gid) =>
              (store, [NotifyError(message="目标分组不存在")])
            _ => {
              let edited = edit_bookmark(
                store.config.groups,
                id,
                display_name,
                u,
                group,
              )
              match edited {
                Some(groups) =>
                  ({ ..store, config: { ..store.config, groups, }, }, [Save])
                None =>
                  (store, [NotifyError(message="要编辑的书签不存在")])
              }
            }
          }
        }
      }
    BookmarkDelete(id~) => {
      let before = count_bookmarks(store.config.groups)
      let groups = map_all_groups(store.config.groups, g => {
        ..g,
        bookmarks: g.bookmarks.filter(b => b.id != id),
      })
      if count_bookmarks(groups) != before {
        ({ ..store, config: { ..store.config, groups, }, }, [Save])
      } else {
        (store, [])
      }
    }
    BookmarkMove(id~, to_group~, to_index~) =>
      if !group_exists(store.config.groups, to_group) {
        (store, [NotifyError(message="目标分组不存在")])
      } else {
        match move_bookmark(store.config.groups, id, to_group, to_index) {
          Some(groups) =>
            ({ ..store, config: { ..store.config, groups, }, }, [Save])
          None => (store, [NotifyError(message="要移动的书签不存在")])
        }
      }
    GroupAdd(name~) => {
      let trimmed = name.trim().to_owned()
      if trimmed == "" {
        (store, [NotifyError(message="分组名称不能为空")])
      } else {
        let groups = store.config.groups.copy()
        groups.push({
          id: @model.next_group_id(store.config.groups),
          name: trimmed,
          bookmarks: [],
          collapsed: false,
        })
        ({ ..store, config: { ..store.config, groups, }, }, [Save])
      }
    }
    GroupRename(id~, name~) =>
      if id == @model.DEFAULT_GROUP_ID {
        (store, [NotifyError(message="默认分组不能重命名")])
      } else {
        let trimmed = name.trim().to_owned()
        if trimmed == "" {
          (store, [NotifyError(message="分组名称不能为空")])
        } else {
          match rename_group(store.config.groups, id, trimmed) {
            Some(groups) =>
              ({ ..store, config: { ..store.config, groups, }, }, [Save])
            None =>
              (store, [NotifyError(message="要编辑的分组不存在")])
          }
        }
      }
    GroupDelete(id~) =>
      if id == @model.DEFAULT_GROUP_ID {
        (store, [NotifyError(message="默认分组不能删除")])
      } else {
        match delete_group(store.config.groups, id) {
          Some(groups) =>
            ({ ..store, config: { ..store.config, groups, }, }, [Save])
          None => (store, [NotifyError(message="要删除的分组不存在")])
        }
      }
    GroupMove(id~, to_index~) =>
      match move_group(store.config.groups, id, to_index) {
        Some(groups) =>
          ({ ..store, config: { ..store.config, groups, }, }, [Save])
        None => (store, [NotifyError(message="要移动的分组不存在")])
      }
    GroupToggleCollapse(id~) =>
      if !group_exists(store.config.groups, id) {
        (store, [NotifyError(message="要折叠的分组不存在")])
      } else {
        let groups = map_groups(store.config.groups, id, g => {
          ..g,
          collapsed: !g.collapsed,
        })
        ({ ..store, config: { ..store.config, groups, }, }, [Save])
      }
    WallpaperBlurSet(amount~) => {
      // clamp to [0, WALLPAPER_BLUR_MAX]; no-op when unchanged
      let clamped = if amount < 0 {
        0
      } else if amount > @model.WALLPAPER_BLUR_MAX {
        @model.WALLPAPER_BLUR_MAX
      } else {
        amount
      }
      if clamped == store.config.wallpaper_blur {
        (store, [])
      } else {
        (
          { ..store, config: { ..store.config, wallpaper_blur: clamped, }, },
          [Save],
        )
      }
    }
    ThemeSet(theme~) =>
      if theme == "dark" || theme == "light" || theme == "auto" {
        if theme == store.config.theme {
          (store, [])
        } else {
          ({ ..store, config: { ..store.config, theme, }, }, [Save])
        }
      } else {
        (store, [NotifyError(message="不支持的主题")])
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
    SearchInput(query~, at~) => {
      // Pure view update: never persists. Empty query -> most recent 6.
      let now = match at {
        Some(t) => t
        None => 0L
      }
      let suggestions = suggest_for(store.config.search.history, query, now)
      ({ ..store, suggestions, }, [])
    }
    SearchSubmit(query~, at~) => {
      let q = query.trim().to_owned()
      if q == "" {
        // search-box spec: empty keyword must not navigate.
        (store, [])
      } else {
        let now = match at {
          Some(t) => t
          None => 0L
        }
        let history = record_search(store.config.search.history, q, now)
        let current = store.config.search.current
        let mut found : @model.Engine? = None
        for e in store.config.search.engines {
          if e.id == current {
            found = Some(e)
          }
        }
        match found {
          Some(engine) => {
            let next = {
              ..store,
              config: {
                ..store.config,
                search: { ..store.config.search, history, },
              },
              // post-submit suggestions reflect the fresh history entry
              suggestions: suggest_for(history, q, now),
            }
            (next, [OpenUrl(url=build_search_url(engine.url_template, q))])
          }
          None =>
            // engine missing: still record the search (it was user intent)
            (
              {
                ..store,
                config: {
                  ..store.config,
                  search: { ..store.config.search, history, },
                },
              },
              [NotifyError(message="未找到当前搜索引擎")],
            )
        }
      }
    }
    HistoryDelete(query~) => {
      let history = store.config.search.history.filter(e => e.query != query)
      (
        {
          ..store,
          config: {
            ..store.config,
            search: { ..store.config.search, history, },
          },
          suggestions: suggest_for(history, query, 0L),
        },
        [Save],
      )
    }
    HistoryClear =>
      (
        {
          ..store,
          config: {
            ..store.config,
            search: { ..store.config.search, history: [], },
          },
          suggestions: [],
        },
        [Save],
      )
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
        // accept both v1 (migrated on decode) and v2 (bookmark-groups D1)
        if cfg.version == 1 || cfg.version == @model.CONFIG_VERSION {
          (
            {
              config: cfg,
              clock: store.clock,
              suggestions: recent_suggestions(cfg.search.history),
            },
            [Save],
          )
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
/// Generate a fresh bookmark id ("b" + next number above all existing ones
/// across every group).
fn next_bookmark_id(groups : Array[@model.Group]) -> String {
  let mut max = 0
  for g in groups {
    for b in g.bookmarks {
      let n = numeric_suffix(b.id)
      if n > max {
        max = n
      }
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
/// Festival first, jieqi only when the day is no festival (spec priority).
fn clock_view_for(date : String) -> ClockView? {
  match parse_ymd(date) {
    Some((y, m, d)) => {
      let lunar = match @lunar.solar_to_lunar(y, m, d) {
        Some(ld) => Some(ld.to_display())
        None => None
      }
      // festival / jieqi derivation needs the full LunarDate
      let festival = match @lunar.solar_to_lunar(y, m, d) {
        Some(ld) => @lunar.festival_for(y, m, d, ld)
        None => None
      }
      let solar_term = match festival {
        // festival wins; skip the term computation (design D5)
        Some(_) => None
        None => @lunar.solar_term(y, m, d)
      }
      Some({
        weekday: @lunar.weekday_name(y, m, d),
        lunar,
        solar_term,
        festival,
      })
    }
    None => None
  }
}
