// Tests for the Netscape bookmark-file parser (bookmark-import tasks 1.1-1.5).

///|
test "parse: standard chrome export" {
  let html =
    #|<!DOCTYPE NETSCAPE-Bookmark-file-1>
    #|<!-- This is an automatically generated file. -->
    #|<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
    #|<TITLE>Bookmarks</TITLE>
    #|<H1>Bookmarks</H1>
    #|<DL><p>
    #|    <DT><H3 ADD_DATE="1695000000" PERSONAL_TOOLBAR_FOLDER="true">工作</H3>
    #|    <DL><p>
    #|        <DT><A HREF="https://github.com/">GitHub</A>
    #|        <DT><A HREF="https://moonbitlang.com/" ADD_DATE="1695000001">MoonBit</A>
    #|    </DL><p>
    #|    <DT><A HREF="https://example.com/">Example</A>
    #|</DL><p>
  match @model.parse_netscape(html) {
    None => fail("expected Some")
    Some(p) => {
      assert_eq(p.top.length(), 1)
      assert_eq(p.top[0].name, "Example")
      assert_eq(p.top[0].url, "https://example.com/")
      assert_eq(p.groups.length(), 1)
      assert_eq(p.groups[0].name, "工作")
      assert_eq(p.groups[0].bookmarks.length(), 2)
      assert_eq(p.groups[0].bookmarks[0].name, "GitHub")
      assert_eq(p.groups[0].bookmarks[0].url, "https://github.com/")
      assert_eq(p.groups[0].bookmarks[1].name, "MoonBit")
    }
  }
}

///|
test "parse: nested folders three deep" {
  let html =
    #|<!DOCTYPE NETSCAPE-Bookmark-file-1>
    #|<DL><p>
    #|<DT><H3>一级</H3>
    #|<DL><p>
    #|<DT><H3>二级</H3>
    #|<DL><p>
    #|<DT><H3>三级</H3>
    #|<DL><p>
    #|<DT><A HREF="https://deep.example/">深</A>
    #|</DL><p>
    #|</DL><p>
    #|</DL><p>
    #|</DL><p>
  match @model.parse_netscape(html) {
    None => fail("expected Some")
    Some(p) => {
      assert_eq(p.groups.map(g => g.name), ["一级", "二级", "三级"])
      // the deep link lands in the innermost open folder ("三级")
      assert_eq(p.groups[2].bookmarks.length(), 1)
      assert_eq(p.groups[0].bookmarks.length(), 0)
    }
  }
}

///|
test "parse: entities decoded in names and urls" {
  let html =
    #|<!DOCTYPE NETSCAPE-Bookmark-file-1>
    #|<DL><p>
    #|<DT><H3>A &amp; B &lt;tag&gt;</H3>
    #|<DL><p>
    #|<DT><A HREF="https://e.example/?q=1&amp;x=2">&quot;q&quot; &#39;s&#39; &#20013; &#x4e66;</A>
    #|</DL><p>
    #|</DL><p>
  match @model.parse_netscape(html) {
    None => fail("expected Some")
    Some(p) => {
      assert_eq(p.groups[0].name, "A & B <tag>")
      assert_eq(p.groups[0].bookmarks[0].name, "\"q\" 's' 中 书")
      assert_eq(p.groups[0].bookmarks[0].url, "https://e.example/?q=1&x=2")
    }
  }
}

///|
test "parse: tolerant of unquoted attrs, case, whitespace, unknown tags" {
  let html = "<!DOCTYPE NETSCAPE-Bookmark-file-1>\n<dL><P>\n<dt><h3 unquoted=bar>组</h3>\n<DL><p>\n<dt><a href=https://plain.example/ >无引号</a>\n<dt><a HREF='https://single.example/'>单引号</a>\n<foo bar>ignored</foo>\n</dl>\n</DL>"
  match @model.parse_netscape(html) {
    None => fail("expected Some")
    Some(p) => {
      assert_eq(p.groups[0].name, "组")
      assert_eq(p.groups[0].bookmarks.length(), 2)
      assert_eq(p.groups[0].bookmarks[0].url, "https://plain.example/")
      assert_eq(p.groups[0].bookmarks[1].url, "https://single.example/")
    }
  }
}

///|
test "parse: missing href or name lines skipped" {
  let html =
    #|<!DOCTYPE NETSCAPE-Bookmark-file-1>
    #|<DL><p>
    #|<DT><A>没有链接</A>
    #|<DT><A HREF="https://nameless.example/"></A>
    #|<DT><A HREF="https://ok.example/">正常</A>
    #|<DT><H3></H3>
    #|</DL><p>
  match @model.parse_netscape(html) {
    None => fail("expected Some")
    Some(p) => {
      assert_eq(p.top.length(), 1)
      assert_eq(p.top[0].name, "正常")
      assert_eq(p.groups.length(), 0)
    }
  }
}

///|
test "parse: rejects non-netscape input" {
  assert_true(@model.parse_netscape("") is None)
  assert_true(@model.parse_netscape("<html><body>hello</body></html>") is None)
  assert_true(
    @model.parse_netscape("<DL><DT><A HREF='https://x/'>x</A></DL>") is None,
  )
}

///|
test "parse: CRLF line endings (windows export)" {
  let html = "<!DOCTYPE NETSCAPE-Bookmark-file-1>\r\n<DL><p>\r\n<DT><H3>组</H3>\r\n<DL><p>\r\n<DT><A HREF=\"https://crlf.example/\">CRLF</A>\r\n</DL><p>\r\n</DL><p>\r\n"
  match @model.parse_netscape(html) {
    None => fail("expected Some")
    Some(p) => assert_eq(p.groups[0].bookmarks[0].name, "CRLF")
  }
}

///|
test "parse: firefox style with folder id attrs and uppercase doctype" {
  let html =
    #|<!DOCTYPE NETSCAPE-Bookmark-file-1>
    #|<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
    #|<DL><p>
    #|    <DT><H3 ADD_DATE="1" LAST_MODIFIED="2" UNFILED_BOOKMARKS_FOLDER="true">未分类</H3>
    #|    <DL><p>
    #|        <DT><A HREF="https://ff.example/" TAGS="a,b">FF</A>
    #|    </DL><p>
    #|</DL><p>
  match @model.parse_netscape(html) {
    None => fail("expected Some")
    Some(p) => {
      assert_eq(p.groups[0].name, "未分类")
      assert_eq(p.groups[0].bookmarks[0].name, "FF")
    }
  }
}

///|
test "decode_entities: named, numeric, unknown, bare ampersand" {
  assert_eq(@model.decode_entities("a&amp;b"), "a&b")
  assert_eq(@model.decode_entities("&lt;&gt;&quot;&apos;"), "<>\"'")
  assert_eq(@model.decode_entities("&#65;&#x42;&#x6C;"), "ABl")
  assert_eq(@model.decode_entities("&nbsp;&unknown;"), "&nbsp;&unknown;")
  assert_eq(@model.decode_entities("a & b"), "a & b")
  assert_eq(@model.decode_entities("no entities"), "no entities")
}
