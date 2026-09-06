// Percent-encoding for search queries (search-box spec): the URL for the
// engine result page is built on the wasm side, so the query must be
// encoded here.

///|
fn hex_digit(n : Int) -> Char {
  match "0123456789ABCDEF".get_char(n) {
    Some(c) => c
    None => '0'
  }
}

///|
fn is_unreserved(code : Int) -> Bool {
  (code >= 'A' && code <= 'Z') ||
  (code >= 'a' && code <= 'z') ||
  (code >= '0' && code <= '9') ||
  code == '-' ||
  code == '_' ||
  code == '.' ||
  code == '~'
}

///|
/// Percent-encode `s` for a URL query slot: unreserved ASCII characters pass
/// through, everything else is UTF-8 percent-encoded.
fn percent_encode(s : String) -> String {
  let buf = StringBuilder()
  for _, ch in s {
    let code = ch.to_int()
    if code < 128 && is_unreserved(code) {
      buf.write_char(ch)
    } else {
      let bytes = @utf8.encode(ch.to_string())
      for i in 0..<bytes.length() {
        let b = bytes[i].to_int()
        buf.write_char('%')
        buf.write_char(hex_digit(b / 16))
        buf.write_char(hex_digit(b % 16))
      }
    }
  }
  buf.to_string()
}

///|
/// Substitute the `{query}` placeholder in an engine URL template. Templates
/// without a placeholder get the encoded query appended.
fn build_search_url(template : String, query : String) -> String {
  let encoded = percent_encode(query)
  if template.contains("{query}") {
    template.replace(old="{query}", new=encoded)
  } else {
    template + encoded
  }
}
