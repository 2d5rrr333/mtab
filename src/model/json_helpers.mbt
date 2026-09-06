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
fn int_field(
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
