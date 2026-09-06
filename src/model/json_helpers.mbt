// JSON decoding helpers shared by the model's FromJson implementations
// and the store's event decoder.

///|
pub fn expect_object(
  json : Json,
  path : @json.JsonPath,
) -> Map[String, Json] raise @json.JsonDecodeError {
  match json {
    Object(map) => map
    _ => raise @json.JsonDecodeError((path, "expected JSON object"))
  }
}

///|
fn field(
  map : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> Json raise @json.JsonDecodeError {
  match map.get(key) {
    Some(json) => json
    None => raise @json.JsonDecodeError((path, "missing field: " + key))
  }
}

///|
pub fn str_field(
  map : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> String raise @json.JsonDecodeError {
  match field(map, key, path) {
    String(s) => s
    _ =>
      raise @json.JsonDecodeError((path, "field " + key + " must be a string"))
  }
}

///|
pub fn int_field(
  map : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> Int raise @json.JsonDecodeError {
  match field(map, key, path) {
    Number(n, ..) => n.to_int()
    _ =>
      raise @json.JsonDecodeError((path, "field " + key + " must be a number"))
  }
}

///|
/// Integer-milliseconds field decoded as Int64: JSON numbers arrive as
/// Double; epoch-ms values stay far below 2^53 so the round trip is exact.
fn int64_field(
  map : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> Int64 raise @json.JsonDecodeError {
  match field(map, key, path) {
    Number(n, ..) => n.to_int64()
    _ =>
      raise @json.JsonDecodeError((path, "field " + key + " must be a number"))
  }
}

///|
/// Optional numeric field: absent or non-number -> None. Lets bridge events
/// carry optional epoch-ms timestamps without a required-field decode path.
pub fn number_field_opt(map : Map[String, Json], key : String) -> Int64? {
  match map.get(key) {
    Some(Number(n, ..)) => Some(n.to_int64())
    _ => None
  }
}

///|
/// Optional string field: absent or non-string -> None.
pub fn str_field_opt(map : Map[String, Json], key : String) -> String? {
  match map.get(key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
fn bool_field(
  map : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> Bool raise @json.JsonDecodeError {
  match field(map, key, path) {
    True => true
    False => false
    _ =>
      raise @json.JsonDecodeError((path, "field " + key + " must be a boolean"))
  }
}

///|
fn array_field(
  map : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> Array[Json] raise @json.JsonDecodeError {
  match field(map, key, path) {
    Array(items) => items
    _ =>
      raise @json.JsonDecodeError((path, "field " + key + " must be an array"))
  }
}
