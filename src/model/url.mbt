// URL normalization for user-entered bookmark addresses (bookmark-grid spec):
// missing scheme gets https://; empty or invalid input is rejected.

///|
/// Whether a host looks plausible: non-empty, no whitespace, and contains a
/// dot, or is exactly "localhost".
fn plausible_host(host : String) -> Bool {
  if host == "" {
    return false
  }
  if host.contains(" ") || host.contains("\t") {
    return false
  }
  host == "localhost" || host.contains(".")
}

///|
/// Collect the host region of `s`: everything after index `from` up to the
/// first '/', '?', '#' or ':' (port separator).
fn extract_host(s : String, from : Int) -> String {
  let buf = StringBuilder()
  for i, ch in s {
    if i < from {
      continue
    }
    if ch == '/' || ch == '?' || ch == '#' || ch == ':' {
      break
    }
    buf.write_char(ch)
  }
  buf.to_string()
}

///|
/// Normalize a user-entered URL. Returns Some(url) with the scheme completed
/// (https:// by default), or None when the input is empty or invalid
/// (bookmark-grid spec: reject with a hint).
pub fn normalize_url(input : String) -> String? {
  let trimmed : String = input.trim().to_owned()
  if trimmed == "" {
    return None
  }
  let lowered = trimmed.to_lower()
  let with_scheme = if lowered.has_prefix("http://") ||
    lowered.has_prefix("https://") {
    trimmed
  } else {
    "https://" + trimmed
  }
  let scheme_end = match with_scheme.find("://") {
    Some(idx) => idx + 3
    None => return None
  }
  let host = extract_host(with_scheme, scheme_end)
  if plausible_host(host) {
    Some(with_scheme)
  } else {
    None
  }
}
