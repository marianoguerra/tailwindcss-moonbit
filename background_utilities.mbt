///|
fn typed_arbitrary(key : String, hint : String) -> String? {
  guard arbitrary_value(key) is Some(value) else { return None }
  let marker = "\{hint}:"
  if value.has_prefix(marker) {
    Some(value[marker.length():].to_owned())
  } else {
    None
  }
}

///|
fn background_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let statics : Array[(String, String, String)] = [
    ("bg-fixed", "background-attachment", "fixed"),
    ("bg-local", "background-attachment", "local"),
    ("bg-scroll", "background-attachment", "scroll"),
    ("bg-clip-border", "background-clip", "border-box"),
    ("bg-clip-padding", "background-clip", "padding-box"),
    ("bg-clip-content", "background-clip", "content-box"),
    ("bg-clip-text", "background-clip", "text"),
    ("bg-origin-border", "background-origin", "border-box"),
    ("bg-origin-padding", "background-origin", "padding-box"),
    ("bg-origin-content", "background-origin", "content-box"),
    ("bg-auto", "background-size", "auto"),
    ("bg-cover", "background-size", "cover"),
    ("bg-contain", "background-size", "contain"),
    ("bg-repeat", "background-repeat", "repeat"),
    ("bg-no-repeat", "background-repeat", "no-repeat"),
    ("bg-repeat-x", "background-repeat", "repeat-x"),
    ("bg-repeat-y", "background-repeat", "repeat-y"),
    ("bg-repeat-round", "background-repeat", "round"),
    ("bg-repeat-space", "background-repeat", "space"),
    ("bg-none", "background-image", "none"),
  ]
  for entry in statics {
    let (candidate, property, value) = entry
    if name == candidate {
      return Some([decl(property, value)])
    }
  }
  let positions : Array[(String, String)] = [
    ("bg-bottom", "bottom"),
    ("bg-center", "center"),
    ("bg-left", "left"),
    ("bg-left-bottom", "left bottom"),
    ("bg-left-top", "left top"),
    ("bg-right", "right"),
    ("bg-right-bottom", "right bottom"),
    ("bg-right-top", "right top"),
    ("bg-top", "top"),
  ]
  for entry in positions {
    let (candidate, value) = entry
    if name == candidate {
      return Some([decl("background-position", value)])
    }
  }
  guard prefixed_value(name, "bg") is Some(key) else { return None }
  match typed_arbitrary(key, "position") {
    Some(value) => return Some([decl("background-position", value)])
    None => ()
  }
  match typed_arbitrary(key, "size") {
    Some(value) => return Some([decl("background-size", value)])
    None => ()
  }
  match arbitrary_value(key) {
    Some(value) =>
      if value.has_prefix("url(") ||
        value.has_prefix("linear-gradient(") ||
        value.has_prefix("radial-gradient(") ||
        value.has_prefix("conic-gradient(") ||
        value.has_prefix("image(") {
        return Some([decl("background-image", value)])
      }
    None => ()
  }
  match theme_css_value(theme, "--background-image-\{key}") {
    Some(value) => Some([decl("background-image", value)])
    None =>
      match theme_css_value(theme, "--background-position-\{key}") {
        Some(value) => Some([decl("background-position", value)])
        None =>
          theme_css_value(theme, "--background-size-\{key}").map(fn(value) {
            [decl("background-size", value)]
          })
      }
  }
}
