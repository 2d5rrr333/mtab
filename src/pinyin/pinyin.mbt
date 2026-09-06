// Pinyin lookup over the packed table (pinyin-suggest design D1).

///|
/// Pinyin of a single character, or None when not in the table.
pub fn pinyin_of(ch : Char) -> String? {
  table().get(ch)
}

///|
/// Concatenated toneless pinyin of every table-covered character in `s`;
/// characters outside the table (spaces, digits, latin, rare hanzi) are
/// skipped entirely.
pub fn phrase_pinyin(s : String) -> String {
  let buf = StringBuilder()
  for _, ch in s {
    match table().get(ch) {
      Some(py) => buf.write_string(py)
      None => ()
    }
  }
  buf.to_string()
}

///|
/// First letter of each table-covered character's pinyin ("春节" -> "cj").
pub fn phrase_initials(s : String) -> String {
  let buf = StringBuilder()
  for _, ch in s {
    match table().get(ch) {
      Some(py) =>
        match py.get_char(0) {
          Some(c) => buf.write_char(c)
          None => ()
        }
      None => ()
    }
  }
  buf.to_string()
}

///|
let table_cache : Ref[Map[Char, String]?] = Ref(None)

///|
fn table() -> Map[Char, String] {
  match table_cache.val {
    Some(m) => m
    None => {
      let m : Map[Char, String] = Map([])
      parse_entries(py_data, m)
      table_cache.val = Some(m)
      m
    }
  }
}

///|
/// Entries are "汉字pinyin" pairs separated by spaces: hanzi is any char
/// above 0x7F, pinyin is the run of ASCII letters that follows it. Any
/// other ASCII character is ignored (defensive against data typos).
fn parse_entries(data : String, into : Map[Char, String]) -> Unit {
  let mut current : Char? = None
  let buf = StringBuilder()
  let mut started = false
  for _, ch in data {
    if ch == ' ' || ch == '\n' || ch == '\t' {
      commit(current, buf, into, started)
      current = None
      buf.reset()
      started = false
    } else if ch.to_int() > 0x7f {
      commit(current, buf, into, started)
      current = Some(ch)
      buf.reset()
      started = false
    } else if (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') {
      buf.write_char(ch)
      started = true
    } else {
      // stray punctuation etc.: end the current pinyin run
      commit(current, buf, into, started)
      buf.reset()
      started = false
    }
  }
  commit(current, buf, into, started)
}

///|
fn commit(
  current : Char?,
  buf : StringBuilder,
  into : Map[Char, String],
  started : Bool,
) -> Unit {
  if started {
    match current {
      Some(c) => into[c] = buf.to_string()
      None => ()
    }
  }
}
