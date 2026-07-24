///|
fn stateful_numeric_value(
  theme : Map[String, String],
  key : String,
  theme_namespace : String,
  unit : String,
) -> String? {
  match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match theme_css_value(theme, "\{theme_namespace}-\{key}") {
        Some(value) => Some(value)
        None =>
          if is_spacing_number(key) {
            if unit == "" {
              Some(key)
            } else {
              Some("\{key}\{unit}")
            }
          } else {
            None
          }
      }
  }
}

///|
fn transform_origin_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  guard prefixed_value(name, "origin") is Some(key) else { return None }
  let keywords : Array[(String, String)] = [
    ("center", "center"),
    ("top", "top"),
    ("top-right", "top right"),
    ("right", "right"),
    ("bottom-right", "bottom right"),
    ("bottom", "bottom"),
    ("bottom-left", "bottom left"),
    ("left", "left"),
    ("top-left", "top left"),
  ]
  for entry in keywords {
    let (candidate, value) = entry
    if key == candidate {
      return Some([decl("transform-origin", value)])
    }
  }
  let value = match arbitrary_value(key) {
    Some(value) => Some(value)
    None => theme_css_value(theme, "--transform-origin-\{key}")
  }
  value.map(fn(value) { [decl("transform-origin", value)] })
}

///|
fn translate_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  if name == "translate-3d" {
    return Some([
      decl(
        "translate", "var(--tw-translate-x) var(--tw-translate-y) var(--tw-translate-z)",
      ),
    ])
  }
  let (root, properties) = if name.has_prefix("translate-x-") {
    ("translate-x", ["--tw-translate-x"])
  } else if name.has_prefix("translate-y-") {
    ("translate-y", ["--tw-translate-y"])
  } else if name.has_prefix("translate-z-") {
    ("translate-z", ["--tw-translate-z"])
  } else if name.has_prefix("translate-") {
    ("translate", ["--tw-translate-x", "--tw-translate-y"])
  } else {
    return None
  }
  guard prefixed_value(name, root) is Some(key) else { return None }
  let value = if key == "full" {
    Some("100%")
  } else {
    match theme_css_value(theme, "--translate-\{key}") {
      Some(value) => Some(value)
      None => resolved_value(theme, key, "--translate", true)
    }
  }
  guard value is Some(value) else { return None }
  let declarations = properties.map(fn(property) { decl(property, value) })
  if root == "translate-z" {
    declarations.push(
      decl(
        "translate", "var(--tw-translate-x) var(--tw-translate-y) var(--tw-translate-z)",
      ),
    )
  } else {
    declarations.push(
      decl("translate", "var(--tw-translate-x) var(--tw-translate-y)"),
    )
  }
  Some(declarations)
}

///|
fn rotate_skew_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let (root, custom_property, function_name) = if name.has_prefix("rotate-x-") {
    ("rotate-x", Some("--tw-rotate-x"), "rotateX")
  } else if name.has_prefix("rotate-y-") {
    ("rotate-y", Some("--tw-rotate-y"), "rotateY")
  } else if name.has_prefix("rotate-z-") {
    ("rotate-z", Some("--tw-rotate-z"), "rotateZ")
  } else if name.has_prefix("skew-x-") {
    ("skew-x", Some("--tw-skew-x"), "skewX")
  } else if name.has_prefix("skew-y-") {
    ("skew-y", Some("--tw-skew-y"), "skewY")
  } else if name.has_prefix("rotate-") {
    ("rotate", None, "")
  } else {
    return None
  }
  guard prefixed_value(name, root) is Some(key) else { return None }
  let theme_namespace = if root.has_prefix("skew") {
    "--skew"
  } else {
    "--rotate"
  }
  guard stateful_numeric_value(theme, key, theme_namespace, "deg")
    is Some(value) else {
    return None
  }
  match custom_property {
    None => Some([decl("rotate", value)])
    Some(property) =>
      Some([
        decl(property, "\{function_name}(\{value})"),
        decl(
          "transform", "var(--tw-rotate-x,) var(--tw-rotate-y,) var(--tw-rotate-z,) var(--tw-skew-x,) var(--tw-skew-y,)",
        ),
      ])
  }
}

///|
fn scale_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let (root, properties) = if name.has_prefix("scale-x-") {
    ("scale-x", ["--tw-scale-x"])
  } else if name.has_prefix("scale-y-") {
    ("scale-y", ["--tw-scale-y"])
  } else if name.has_prefix("scale-z-") {
    ("scale-z", ["--tw-scale-z"])
  } else if name.has_prefix("scale-") {
    ("scale", ["--tw-scale-x", "--tw-scale-y", "--tw-scale-z"])
  } else {
    return None
  }
  guard prefixed_value(name, root) is Some(key) else { return None }
  let value = match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match theme_css_value(theme, "--scale-\{key}") {
        Some(value) => Some(value)
        None => if is_spacing_number(key) { Some("\{key}%") } else { None }
      }
  }
  guard value is Some(value) else { return None }
  let declarations = properties.map(fn(property) { decl(property, value) })
  declarations.push(decl("scale", "var(--tw-scale-x) var(--tw-scale-y)"))
  Some(declarations)
}

///|
fn perspective_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  if name.has_prefix("perspective-origin-") {
    let key = name[19:].to_owned()
    // A theme key resolves under both `--perspective-origin-*` and, read as
    // `perspective-origin-<key>`, under `--perspective-*`, so upstream compiles
    // the candidate against both roots. An arbitrary value only matches the
    // `perspective-origin` root.
    match arbitrary_value(key) {
      Some(value) => return Some([decl("perspective-origin", value)])
      None => ()
    }
    return theme_css_value(theme, "--perspective-origin-\{key}").map(fn(value) {
      [decl("perspective-origin", value), decl("perspective", value)]
    })
  }
  guard prefixed_value(name, "perspective") is Some(key) else { return None }
  let value = match key {
    "none" => Some("none")
    _ =>
      match arbitrary_value(key) {
        Some(value) => Some(value)
        None => theme_css_value(theme, "--perspective-\{key}")
      }
  }
  value.map(fn(value) { [decl("perspective", value)] })
}

///|
fn stateful_transform_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  match name {
    "transform-flat" => return Some([decl("transform-style", "flat")])
    "transform-3d" => return Some([decl("transform-style", "preserve-3d")])
    "transform-none" => return Some([decl("transform", "none")])
    "transform" | "transform-cpu" =>
      return Some([
        decl(
          "transform", "var(--tw-rotate-x,) var(--tw-rotate-y,) var(--tw-rotate-z,) var(--tw-skew-x,) var(--tw-skew-y,)",
        ),
      ])
    "transform-gpu" =>
      return Some([
        decl(
          "transform", "translateZ(0) var(--tw-rotate-x,) var(--tw-rotate-y,) var(--tw-rotate-z,) var(--tw-skew-x,) var(--tw-skew-y,)",
        ),
      ])
    "transform-view" => return Some([decl("transform-box", "view-box")])
    _ => ()
  }
  match transform_origin_utility(theme, name) {
    Some(value) => return Some(value)
    None => ()
  }
  match translate_utility(theme, name) {
    Some(value) => return Some(value)
    None => ()
  }
  match rotate_skew_utility(theme, name) {
    Some(value) => return Some(value)
    None => ()
  }
  match scale_utility(theme, name) {
    Some(value) => return Some(value)
    None => perspective_utility(theme, name)
  }
}
