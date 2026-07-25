///|
/// Read a top-level field from a JSON object, or `None` if absent / not an object.
fn json_field(node : Json, key : String) -> Json? {
  match node {
    Object(fields) => fields.get(key)
    _ => None
  }
}

///|
/// Extract a string from an optional JSON node.
fn json_string(node : Json?) -> String? {
  match node {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
/// Extract the non-blank strings of an optional JSON array.
fn json_strings(node : Json?) -> Array[String] {
  let values : Array[String] = []
  match node {
    Some(Array(items)) =>
      for item in items {
        match item {
          String(text) => {
            let trimmed = text.trim().to_owned()
            if trimmed != "" {
              values.push(trimmed)
            }
          }
          _ => ()
        }
      }
    _ => ()
  }
  values
}

///|
fn json_count(value : Int) -> Json {
  Json::number(value.to_double())
}

///|
fn candidates_json(candidates : Array[String]) -> Json {
  Json::array(candidates.map(Json::string))
}

///|
/// A `{"ok":false,"error":...}` reply. Every entry point returns a JSON string
/// rather than raising, so a host never has to guess whether it got CSS or a
/// failure.
fn error_result(message : String) -> String {
  Json::object(
    Map([("ok", Json::boolean(false)), ("error", Json::string(message))]),
  ).stringify()
}
