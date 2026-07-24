///|
fn border_width_value(theme : Map[String, String], key : String) -> String? {
  if key == "" {
    return Some("1px")
  }
  match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match theme_css_value(theme, "--border-width-\{key}") {
        Some(value) => Some(value)
        None =>
          if is_nonnegative_integer(key) {
            Some("\{key}px")
          } else {
            None
          }
      }
  }
}

///|
fn border_width_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let entries : Array[(String, String, String)] = [
    ("border-x", "border-inline-style", "border-inline-width"),
    ("border-y", "border-block-style", "border-block-width"),
    ("border-s", "border-inline-start-style", "border-inline-start-width"),
    ("border-e", "border-inline-end-style", "border-inline-end-width"),
    ("border-bs", "border-block-start-style", "border-block-start-width"),
    ("border-be", "border-block-end-style", "border-block-end-width"),
    ("border-t", "border-top-style", "border-top-width"),
    ("border-r", "border-right-style", "border-right-width"),
    ("border-b", "border-bottom-style", "border-bottom-width"),
    ("border-l", "border-left-style", "border-left-width"),
    ("border", "border-style", "border-width"),
  ]
  for entry in entries {
    let (root, style_property, width_property) = entry
    let key = if name == root {
      ""
    } else {
      guard prefixed_value(name, root) is Some(key) else { continue }
      key
    }
    guard border_width_value(theme, key) is Some(value) else { continue }
    return Some([
      decl(style_property, "var(--tw-border-style)"),
      decl(width_property, value),
    ])
  }
  None
}

///|
fn border_style_utility(name : String) -> Array[Declaration]? {
  guard prefixed_value(name, "border") is Some(style) else { return None }
  guard ["solid", "dashed", "dotted", "double", "hidden", "none"].contains(
    style,
  ) else {
    return None
  }
  Some([decl("--tw-border-style", style), decl("border-style", style)])
}

///|
fn radius_value(theme : Map[String, String], key : String) -> String? {
  match key {
    "" => Some("0.25rem")
    "none" => Some("0")
    "full" => Some("calc(infinity * 1px)")
    _ =>
      match arbitrary_value(key) {
        Some(value) => Some(value)
        None => theme_css_value(theme, "--radius-\{key}")
      }
  }
}

///|
fn radius_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let entries : Array[(String, Array[String])] = [
    ("rounded-ss", ["border-start-start-radius"]),
    ("rounded-se", ["border-start-end-radius"]),
    ("rounded-ee", ["border-end-end-radius"]),
    ("rounded-es", ["border-end-start-radius"]),
    ("rounded-tl", ["border-top-left-radius"]),
    ("rounded-tr", ["border-top-right-radius"]),
    ("rounded-br", ["border-bottom-right-radius"]),
    ("rounded-bl", ["border-bottom-left-radius"]),
    ("rounded-s", ["border-start-start-radius", "border-end-start-radius"]),
    ("rounded-e", ["border-start-end-radius", "border-end-end-radius"]),
    ("rounded-t", ["border-top-left-radius", "border-top-right-radius"]),
    ("rounded-r", ["border-top-right-radius", "border-bottom-right-radius"]),
    ("rounded-b", ["border-bottom-right-radius", "border-bottom-left-radius"]),
    ("rounded-l", ["border-top-left-radius", "border-bottom-left-radius"]),
    ("rounded", ["border-radius"]),
  ]
  for entry in entries {
    let (root, properties) = entry
    let key = if name == root {
      ""
    } else {
      guard prefixed_value(name, root) is Some(key) else { continue }
      key
    }
    guard radius_value(theme, key) is Some(value) else { continue }
    return Some(properties.map(fn(property) { decl(property, value) }))
  }
  None
}

///|
fn outline_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  if name.has_prefix("outline-offset-") {
    let key = name[15:].to_owned()
    let value = match arbitrary_value(key) {
      Some(value) => Some(value)
      None =>
        if is_nonnegative_integer(key) {
          Some("\{key}px")
        } else {
          theme_css_value(theme, "--outline-offset-\{key}")
        }
    }
    return value.map(fn(value) { [decl("outline-offset", value)] })
  }
  let styles = ["solid", "dashed", "dotted", "double", "none", "hidden"]
  let key = if name == "outline" {
    ""
  } else {
    match prefixed_value(name, "outline") {
      Some(key) => key
      None => return None
    }
  }
  if styles.contains(key) {
    let style = if key == "hidden" { "none" } else { key }
    return Some([
      decl("--tw-outline-style", style),
      decl("outline-style", style),
    ])
  }
  guard border_width_value(theme, key) is Some(value) else { return None }
  Some([
    decl("outline-style", "var(--tw-outline-style)"),
    decl("outline-width", value),
  ])
}

///|
fn stroke_width_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  guard prefixed_value(name, "stroke") is Some(key) else { return None }
  let value = match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match theme_css_value(theme, "--stroke-width-\{key}") {
        Some(value) => Some(value)
        None => if is_nonnegative_integer(key) { Some(key) } else { None }
      }
  }
  value.map(fn(value) { [decl("stroke-width", value)] })
}

///|
fn border_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  match radius_utility(theme, name) {
    Some(value) => return Some(value)
    None => ()
  }
  match border_style_utility(name) {
    Some(value) => return Some(value)
    None => ()
  }
  match border_width_utility(theme, name) {
    Some(value) => return Some(value)
    None => ()
  }
  match outline_utility(theme, name) {
    Some(value) => return Some(value)
    None => stroke_width_utility(theme, name)
  }
}
