// Bridge events (design D2): the closed enum the JS shell may dispatch.
// On the wire they are JSON objects with a snake_case "type" tag.

///|
pub(all) enum Event {
  BookmarkAdd(name~ : String, url~ : String)
  BookmarkEdit(id~ : String, name~ : String, url~ : String)
  BookmarkDelete(id~ : String)
  EngineSelect(id~ : String)
  SearchSubmit(query~ : String)
  WidgetToggle(widget~ : String)
  WallpaperSetBuiltin(id~ : String)
  WallpaperSetCustom(data~ : String)
  ConfigImport(json~ : String)
  TickDate(date~ : String)
} derive(Eq, Debug)

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
      )
    "bookmark_edit" =>
      BookmarkEdit(
        id=@model.str_field(map, "id", path),
        name=@model.str_field(map, "name", path),
        url=@model.str_field(map, "url", path),
      )
    "bookmark_delete" => BookmarkDelete(id=@model.str_field(map, "id", path))
    "engine_select" => EngineSelect(id=@model.str_field(map, "id", path))
    "search_submit" => SearchSubmit(query=@model.str_field(map, "query", path))
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
