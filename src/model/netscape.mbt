// Netscape bookmark-file parser (bookmark-import design D1/D2/D5):
// a single-pass, regex-free, allocation-light tokenizer over the
// Chrome/Firefox/Edge "NETSCAPE-Bookmark-file" HTML export format.
//
// Tolerated real-world deviations: case-insensitive tags, unquoted
// attribute values, extra whitespace, unknown tags, comments, CRLF.
// Rejected: anything without the NETSCAPE-Bookmark-file doctype.

///|
/// One bookmark pulled out of a `<DT><A HREF=...>name</A>` entry.
pub(all) struct ParsedBookmark {
  name : String
  url : String
} derive(Eq, Debug)

///|
/// One named folder (H3) with its bookmarks; nesting is flattened by
/// the parser into the group list in document order.
pub(all) struct ParsedGroup {
  name : String
  bookmarks : Array[ParsedBookmark]
} derive(Eq, Debug)

///|
/// Parse output: named groups in document order plus top-level
/// (outside any H3 folder) bookmarks.
pub(all) struct ParseResult {
  top : Array[ParsedBookmark]
  groups : Array[ParsedGroup]
} derive(Eq, Debug)

///|
/// The import guard from design D6: refuse absurdly large payloads.
pub const NETSCAPE_MAX_HTML : Int = 5 * 1024 * 1024

///|
/// Parse a Netscape bookmark file. None when the input is missing the
/// NETSCAPE-Bookmark-file doctype or exceeds the size guard.
pub fn parse_netscape(html : String) -> ParseResult? {
  if html.length() > NETSCAPE_MAX_HTML {
    return None
  }
  if !has_netscape_doctype(html) {
    return None
  }
  let top : Array[ParsedBookmark] = []
  let groups : Array[ParsedGroup] = []
  // stack of open folder indices into `groups` (design D2)
  let stack : Array[Int] = []
  // pending entry from <DT>: what the next H3/A attaches to
  let mut pending : PendingEntry = Nothing
  let n = html.length()
  let mut i = 0
  while i < n {
    if html[i] == '<' {
      // comment: skip through -->
      if starts_with_ci(html, i, "<!--") {
        match find_from(html, "-->", i) {
          Some(end) => {
            i = end + 3
            continue
          }
          None => break
        }
      }
      // find end of tag
      match find_from(html, ">", i) {
        None => break
        Some(gt) => {
          let raw : String = html[i + 1:gt].to_owned()
          let tag = parse_tag(raw)
          if tag is Some(t) {
            pending = apply_tag(t, html, gt + 1, top, groups, stack, pending)
          }
          i = gt + 1
        }
      }
    } else {
      i = i + 1
    }
  }
  Some({ top, groups, })
}

///|
/// Offset of `needle` at or after `from`, None when absent.
fn find_from(s : String, needle : String, from : Int) -> Int? {
  let n = s.length()
  let m = needle.length()
  let mut i = from
  while i + m <= n {
    if s[i] == needle[0] {
      let mut j = 0
      let mut hit = true
      while j < m {
        if s[i + j] != needle[j] {
          hit = false
          break
        }
        j = j + 1
      }
      if hit {
        return Some(i)
      }
    }
    i = i + 1
  }
  None
}

///|
/// What the parser is currently holding between a structure tag and its
/// scope (design D2). `DT` entries are accepted with or without the
/// preceding `<DT>` (tolerance), so it only tracks pending scopes.
priv enum PendingEntry {
  Nothing // no folder or link pending
  Folder(name~ : String) // H3 seen, waiting for its DL scope
  Link(url~ : String, name~ : String) // A seen, lands at the closing </A>
}

///|
/// One parsed tag: name plus ordered attributes (name, value).
priv struct Tag {
  name : String
  attrs : Array[(String, String)]
}

///|
/// Case-insensitive `<...>` content parser. `raw` excludes the brackets.
/// Returns None for degenerate tags like "<>" or "</>"; closing tags are
/// reported with a "/"-prefixed name.
fn parse_tag(raw : String) -> Tag? {
  let trimmed = raw.trim().to_owned()
  if trimmed == "" {
    return None
  }
  let (name, rest) = split_tag_name(trimmed)
  if name == "" {
    return None
  }
  let attrs : Array[(String, String)] = []
  let n = rest.length()
  let mut i = 0
  while i < n {
    // skip whitespace
    while i < n && is_ws(rest[i]) {
      i = i + 1
    }
    if i >= n {
      break
    }
    // attribute name up to '=', ws or end
    let name_start = i
    while i < n && rest[i] != '=' && !is_ws(rest[i]) {
      i = i + 1
    }
    let attr_name : String = lower(rest[name_start:i].to_owned())
    if attr_name == "" {
      i = i + 1
      continue
    }
    // skip ws; expect '=' or nothing (bare attribute)
    while i < n && is_ws(rest[i]) {
      i = i + 1
    }
    if i < n && rest[i] == '=' {
      i = i + 1
      while i < n && is_ws(rest[i]) {
        i = i + 1
      }
      if i < n && (rest[i] == '"' || rest[i] == '\'') {
        let quote = rest[i]
        i = i + 1
        let vstart = i
        while i < n && rest[i] != quote {
          i = i + 1
        }
        attrs.push((attr_name, rest[vstart:i].to_owned()))
        if i < n {
          i = i + 1 // closing quote
        }
      } else {
        let vstart = i
        while i < n && !is_ws(rest[i]) {
          i = i + 1
        }
        attrs.push((attr_name, rest[vstart:i].to_owned()))
      }
    } else {
      attrs.push((attr_name, ""))
    }
  }
  Some({ name, attrs, })
}

///|
/// Split "<name rest...>" into the lowercased tag name and the rest.
/// Closing tags keep their leading '/' on the name ("/DL").
fn split_tag_name(s : String) -> (String, String) {
  let n = s.length()
  let mut i = 0
  while i < n && is_ws(s[i]) {
    i = i + 1
  }
  let start = i
  while i < n && !is_ws(s[i]) {
    i = i + 1
  }
  (lower(s[start:i].to_owned()), s[i:n].to_owned())
}

///|
/// Tag dispatch against the parse state (design D2): DL stack pushes and
/// pops, DT arms a pending entry, H3/A under DT capture name/url, and the
/// entry lands when its closing tag (or the next structure tag) arrives.
fn apply_tag(
  tag : Tag,
  html : String,
  text_start : Int,
  top : Array[ParsedBookmark],
  groups : Array[ParsedGroup],
  stack : Array[Int],
  pending : PendingEntry,
) -> PendingEntry {
  match tag.name {
    "dt" => pending // <DT> prefix; the following H3/A carries the payload
    "dl" =>
      // a DL right after a pending folder H3 opens that folder's scope
      match pending {
        Folder(name~) => {
          let idx = groups.length()
          groups.push({ name, bookmarks: [], })
          stack.push(idx)
          Nothing
        }
        _ => pending
      }
    "/dl" => {
      ignore(stack.pop())
      Nothing
    }
    "h3" => {
      // folder name lives between the open tag and </H3>; decode entities
      let name = decode_entities(tag_text(html, text_start))
      if name == "" {
        Nothing
      } else {
        Folder(name~)
      }
    }
    "a" => {
      let url = attr_value(tag.attrs, "href")
      match url {
        Some(u) => {
          // bookmark name lives between the open tag and </A>
          let name = tag_text(html, text_start)
          if name == "" {
            Nothing // nameless entry: skip (spec: invalid lines skipped)
          } else {
            Link(url=decode_entities(u), name=decode_entities(name))
          }
        }
        None => Nothing // no HREF: skip
      }
    }
    "/a" =>
      match pending {
        Link(url~, name~) => {
          land_bookmark(top, groups, stack, { name, url, })
          Nothing
        }
        other => other
      }
    "/h3" => pending // folder name already captured at open tag
    "p" => pending // stray <p> separators between DT entries
    _ => pending // unknown tags tolerated (spec: parsing tolerance)
  }
}

///|
/// Place a finished bookmark into the innermost open folder, or the
/// top-level list when no folder is open.
fn land_bookmark(
  top : Array[ParsedBookmark],
  groups : Array[ParsedGroup],
  stack : Array[Int],
  b : ParsedBookmark,
) -> Unit {
  match stack.last() {
    Some(idx) => groups[idx].bookmarks.push(b)
    None => top.push(b)
  }
}

///|
/// The raw text between a tag's `>` and the next `<`: the entry name.
fn tag_text(html : String, from : Int) -> String {
  let end = match find_from(html, "<", from) {
    Some(idx) => idx
    None => html.length()
  }
  html[from:end].trim().to_owned()
}

///|
/// First value of `name` in attrs, if present and non-empty.
fn attr_value(attrs : Array[(String, String)], name : String) -> String? {
  for pair in attrs {
    if pair.0 == name && pair.1 != "" {
      return Some(pair.1)
    }
  }
  None
}

///|
/// Doctype check (design D1): case-insensitive "NETSCAPE-Bookmark-file"
/// anywhere in the first chunk of the document.
fn has_netscape_doctype(html : String) -> Bool {
  let probe = "netscape-bookmark-file"
  let limit = if html.length() < 512 { html.length() } else { 512 }
  let head : String = lower(html[0:limit].to_owned())
  head.contains(probe)
}

///|
/// Lowercase ASCII (tag and attribute names are ASCII in this format).
fn lower(s : String) -> String {
  let buf = StringBuilder()
  for c in s {
    if c >= 'A' && c <= 'Z' {
      buf.write_char((c.to_int() + 32).unsafe_to_char())
    } else {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Whitespace test on a UTF-16 code unit (mixed code-unit/char comparisons
/// are builtin, as in group.mbt's numeric_gid_suffix).
fn is_ws(c : UInt16) -> Bool {
  c == ' ' || c == '\t' || c == '\r' || c == '\n'
}

///|
/// Case-insensitive has-prefix at an index.
fn starts_with_ci(s : String, at : Int, prefix : String) -> Bool {
  if at + prefix.length() > s.length() {
    return false
  }
  lower(s[at:at + prefix.length()].to_owned()) == prefix
}

///|
/// Decode the five named entities browsers actually emit plus numeric
/// entities (design D5); unknown entities pass through untouched.
pub fn decode_entities(s : String) -> String {
  if !s.contains("&") {
    return s
  }
  let buf = StringBuilder()
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = s[i]
    if c != '&' {
      // verbatim copy (UTF-16 code unit passthrough; surrogate pairs
      // pass through adjacent units untouched)
      buf.write_string(s[i:i + 1].to_owned())
      i = i + 1
      continue
    }
    // find the terminating ';' within a sane window
    let mut j = i + 1
    let mut semi = -1
    while j < n && j - i <= 10 {
      if s[j] == ';' {
        semi = j
        break
      }
      j = j + 1
    }
    if semi < 0 {
      buf.write_string(s[i:i + 1].to_owned())
      i = i + 1
      continue
    }
    let ent : String = s[i + 1:semi].to_owned()
    match decode_entity(ent) {
      Some(ch) => {
        buf.write_char(ch)
        i = semi + 1
      }
      None => {
        // unknown entity: keep verbatim
        buf.write_string(s[i:i + 1].to_owned())
        i = i + 1
      }
    }
  }
  buf.to_string()
}

///|
/// One entity body (without & and ;) to its char, or None.
fn decode_entity(ent : String) -> Char? {
  match ent {
    "amp" => Some('&')
    "lt" => Some('<')
    "gt" => Some('>')
    "quot" => Some('"')
    "apos" => Some('\'')
    "#39" => Some('\'')
    _ =>
      if ent.length() > 1 && ent[0] == '#' {
        let hex = ent[1] == 'x' || ent[1] == 'X'
        let body : String = if hex {
          ent[2:ent.length()].to_owned()
        } else {
          ent[1:ent.length()].to_owned()
        }
        match parse_codepoint(body, hex) {
          Some(cp) => if cp > 0 && cp <= 0x10FFFF { cp.to_char() } else { None }
          None => None
        }
      } else {
        None
      }
  }
}

///|
/// Parse a decimal (hex=false) or hexadecimal (hex=true) codepoint.
fn parse_codepoint(s : String, hex : Bool) -> Int? {
  if s == "" {
    return None
  }
  let mut n = 0
  for c in s {
    let d = if c >= '0' && c <= '9' {
      c.to_int() - '0'.to_int()
    } else if hex && c >= 'a' && c <= 'f' {
      c.to_int() - 'a'.to_int() + 10
    } else if hex && c >= 'A' && c <= 'F' {
      c.to_int() - 'A'.to_int() + 10
    } else {
      return None
    }
    n = n * (if hex { 16 } else { 10 }) + d
  }
  Some(n)
}
