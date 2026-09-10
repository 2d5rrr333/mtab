// Bookmark import reducer tests (bookmark-import tasks 2.1 / 2.3 / 2.4 / 2.5).

///|
fn import_html(groups_and_links : String) -> String {
  "<!DOCTYPE NETSCAPE-Bookmark-file-1>\n<DL><p>\n" +
  groups_and_links +
  "</DL><p>\n"
}

///|
/// A store with an explicitly empty default group (the shipped default
/// config carries starter bookmarks; import tests need a blank grid).
fn empty_import_store(today : String) -> @store.Store {
  let cfg = { ..@model.Config::default(), groups: [], }
  @store.open(Some(cfg.encode()), today).state
}

///|
test "bookmark_import event decodes from bridge JSON (task 2.1)" {
  let json = @json.parse(
    "{\"type\":\"bookmark_import\",\"html\":\"<!DOCTYPE NETSCAPE-Bookmark-file-1>\"}",
  )
  let event : Event = @json.from_json(json)
  assert_eq(event, BookmarkImport(html="<!DOCTYPE NETSCAPE-Bookmark-file-1>"))
}

///|
test "import merges into same-name group instead of creating one" {
  // existing store with group "工作"
  let base = @store.open(None, "2025-01-29").state
  let with_group = @store.update(base, GroupAdd(name="工作")).state
  let html = import_html(
    "  <DT><H3>工作</H3>\n  <DL><p>\n  <DT><A HREF=\"https://a.example/\">A</A>\n  </DL><p>\n",
  )
  let resp = @store.update(with_group, BookmarkImport(html~))
  // no new group, one new bookmark in the existing "工作"
  let groups = resp.state.config.groups
  assert_eq(groups.length(), 2) // 默认分组 + 工作
  assert_eq(groups[1].name, "工作")
  assert_eq(groups[1].bookmarks.length(), 1)
  assert_eq(groups[1].bookmarks[0].url, "https://a.example/")
  // Save + Toast with group count 0
  assert_eq(resp.effects[0], Save)
  assert_eq(
    resp.effects[1],
    Toast(message="导入完成：新增 0 组 1 条书签"),
  )
}

///|
test "import dedupes urls against existing and in-batch entries" {
  let base = empty_import_store("2025-01-29")
  let with_bm = @store.update(
      base,
      BookmarkAdd(name="已有", url="https://dup.example/", group=None),
    ).state
  let html = import_html(
    "  <DT><A HREF=\"https://dup.example/\">重复</A>\n  <DT><A HREF=\"https://new.example/\">新</A>\n  <DT><A HREF=\"https://new.example/\">本批重复</A>\n  <DT><A HREF=\"javascript:void(0)\">无效</A>\n",
  )
  let resp = @store.update(with_bm, BookmarkImport(html~))
  let bookmarks = resp.state.config.groups[0].bookmarks
  assert_eq(bookmarks.length(), 2) // 已有 + 新
  assert_eq(bookmarks[1].url, "https://new.example/")
  assert_eq(
    resp.effects[1],
    Toast(
      message="导入完成：新增 0 组 1 条书签，跳过 3 条重复或无效",
    ),
  )
}

///|
test "import appends new groups after existing ones (order kept)" {
  let base = @store.open(None, "2025-01-29").state
  let with_group = @store.update(base, GroupAdd(name="已有组")).state
  let html = import_html(
    "  <DT><H3>新组</H3>\n  <DL><p>\n  <DT><A HREF=\"https://n.example/\">N</A>\n  </DL><p>\n",
  )
  let resp = @store.update(with_group, BookmarkImport(html~))
  let groups = resp.state.config.groups
  assert_eq(groups.length(), 3)
  assert_eq(groups[0].name, "默认分组") // default stays first
  assert_eq(groups[1].name, "已有组") // existing order kept
  assert_eq(groups[2].name, "新组") // new group appended last
  assert_eq(
    resp.effects[1],
    Toast(message="导入完成：新增 1 组 1 条书签"),
  )
}

///|
test "import top-level bookmarks land in the default group" {
  let base = empty_import_store("2025-01-29")
  let html = import_html("  <DT><A HREF=\"https://top.example/\">顶层</A>\n")
  let resp = @store.update(base, BookmarkImport(html~))
  let groups = resp.state.config.groups
  assert_eq(groups[0].id, "g0")
  assert_eq(groups[0].bookmarks.length(), 1)
  assert_eq(groups[0].bookmarks[0].name, "顶层")
}

///|
test "import rejects invalid files without touching state" {
  let base = @store.open(None, "2025-01-29").state
  let resp = @store.update(
    base,
    BookmarkImport(html="<html>not bookmarks</html>"),
  )
  assert_eq(resp.state, base)
  assert_eq(resp.effects, [
    NotifyError(message="导入失败：不是有效的浏览器书签文件"),
  ])
}

///|
test "import with nothing importable reports and does not save" {
  let base = @store.open(None, "2025-01-29").state
  let html = import_html("  <DT><A HREF=\"https://dup.example/\">A</A>\n")
  let once = @store.update(base, BookmarkImport(html~)).state
  let twice = @store.update(once, BookmarkImport(html~))
  assert_eq(twice.state, once) // nothing changed
  assert_eq(twice.effects, [
    Toast(message="未导入新内容：跳过 1 条重复或无效书签"),
  ])
}

///|
test "import caps total bookmarks and counts overflow as skipped" {
  // build a store holding IMPORT_BOOKMARK_LIMIT - 1 bookmarks via import
  let base = empty_import_store("2025-01-29")
  let mut entries = ""
  for i in 0..<(IMPORT_BOOKMARK_LIMIT - 1) {
    entries = entries +
      "  <DT><A HREF=\"https://bulk" +
      i.to_string() +
      ".example/\">B" +
      i.to_string() +
      "</A>\n"
  }
  let bulk = import_html(entries)
  let loaded = @store.update(base, BookmarkImport(html=bulk)).state
  let count = loaded.config.groups[0].bookmarks.length()
  assert_eq(count, IMPORT_BOOKMARK_LIMIT - 1)
  // importing 2 more: only 1 fits, the other counts as skipped
  let extra = import_html(
    "  <DT><A HREF=\"https://over1.example/\">O1</A>\n  <DT><A HREF=\"https://over2.example/\">O2</A>\n",
  )
  let resp = @store.update(loaded, BookmarkImport(html=extra))
  assert_eq(
    resp.state.config.groups[0].bookmarks.length(),
    IMPORT_BOOKMARK_LIMIT,
  )
  assert_eq(
    resp.effects[1],
    Toast(
      message="导入完成：新增 0 组 1 条书签，跳过 1 条重复或无效",
    ),
  )
}

///|
test "import 5MB guard rejects oversized payloads" {
  let base = @store.open(None, "2025-01-29").state
  // header (passes doctype) + junk padding beyond the guard
  let mut huge = "<!DOCTYPE NETSCAPE-Bookmark-file-1>\n"
  while huge.length() <= @model.NETSCAPE_MAX_HTML {
    huge = huge + "<!-- padding padding padding padding padding padding -->"
  }
  let resp = @store.update(base, BookmarkImport(html=huge))
  assert_eq(resp.state, base)
  assert_eq(resp.effects, [
    NotifyError(message="导入失败：不是有效的浏览器书签文件"),
  ])
}
