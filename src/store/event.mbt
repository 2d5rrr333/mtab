// Bridge events (design D2): the closed enum the JS shell may dispatch.
// On the wire they are JSON objects with a snake_case "type" tag.

///|
pub(all) enum Event {
  BookmarkAdd(name~ : String, url~ : String, group~ : String?)
  BookmarkEdit(id~ : String, name~ : String, url~ : String, group~ : String?)
  BookmarkDelete(id~ : String)
  BookmarkMove(id~ : String, to_group~ : String, to_index~ : Int)
  GroupAdd(name~ : String)
  GroupRename(id~ : String, name~ : String)
  GroupDelete(id~ : String)
  GroupMove(id~ : String, to_index~ : Int)
  GroupToggleCollapse(id~ : String)
  WallpaperBlurSet(amount~ : Int)
  ThemeSet(theme~ : String)
  EngineSelect(id~ : String)
  SearchInput(query~ : String, at~ : Int64?)
  SearchSubmit(query~ : String, at~ : Int64?)
  HistoryDelete(query~ : String)
  HistoryClear
  WidgetToggle(widget~ : String)
  WallpaperSetBuiltin(id~ : String)
  WallpaperSetCustom(data~ : String)
  ConfigImport(json~ : String)
  TickDate(date~ : String)
} derive(Eq, Debug)

///|
/// Optional group target for bookmark add/edit: absent -> None (default
/// group semantics live in the reducer).
fn group_field(map : Map[String, Json]) -> String? {
  @model.str_field_opt(map, "group")
}

///|
/// Optional epoch-ms "at" field: absent or non-number -> None. Old callers
// (pre search-history) never send it; 0 is a valid "no decay" timestamp.
fn at_field(map : Map[String, Json]) -> Int64? {
  @model.number_field_opt(map, "at")
}

///|
pub impl FromJson for Event with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> Event raise @json.JsonDecodeError {
  let map = @model.expect_object(json, path)
  match @model.str_field(map, "type", path) {
    "bookmark_add" =>
      BookmarkAdd(
        name=@model.str_field(map, "name", path),
        url=@model.str_field(map, "url", path),
        group=group_field(map),
      )
    "bookmark_edit" =>
      BookmarkEdit(
        id=@model.str_field(map, "id", path),
        name=@model.str_field(map, "name", path),
        url=@model.str_field(map, "url", path),
        group=group_field(map),
      )
    "bookmark_delete" => BookmarkDelete(id=@model.str_field(map, "id", path))
    "bookmark_move" =>
      BookmarkMove(
        id=@model.str_field(map, "id", path),
        to_group=@model.str_field(map, "to_group", path),
        to_index=@model.int_field(map, "to_index", path),
      )
    "group_add" => GroupAdd(name=@model.str_field(map, "name", path))
    "group_rename" =>
      GroupRename(
        id=@model.str_field(map, "id", path),
        name=@model.str_field(map, "name", path),
      )
    "group_delete" => GroupDelete(id=@model.str_field(map, "id", path))
    "group_move" =>
      GroupMove(
        id=@model.str_field(map, "id", path),
        to_index=@model.int_field(map, "to_index", path),
      )
    "group_toggle_collapse" =>
      GroupToggleCollapse(id=@model.str_field(map, "id", path))
    "wallpaper_blur_set" =>
      WallpaperBlurSet(amount=@model.int_field(map, "amount", path))
    "theme_set" => ThemeSet(theme=@model.str_field(map, "theme", path))
    "engine_select" => EngineSelect(id=@model.str_field(map, "id", path))
    "search_input" =>
      SearchInput(query=@model.str_field(map, "query", path), at=at_field(map))
    "search_submit" =>
      SearchSubmit(query=@model.str_field(map, "query", path), at=at_field(map))
    "history_delete" =>
      HistoryDelete(query=@model.str_field(map, "query", path))
    "history_clear" => HistoryClear
    "widget_toggle" =>
      WidgetToggle(widget=@model.str_field(map, "widget", path))
    "wallpaper_set_builtin" =>
      WallpaperSetBuiltin(id=@model.str_field(map, "id", path))
    "wallpaper_set_custom" =>
      WallpaperSetCustom(data=@model.str_field(map, "data", path))
    "config_import" => ConfigImport(json=@model.str_field(map, "json", path))
    "tick_date" => TickDate(date=@model.str_field(map, "date", path))
    other => raise @json.JsonDecodeError((path, "unknown event type: " + other))
  }
}
