///|
/// Whether an arbitrary value is a measurement rather than a color: either it
/// says so with a typehint, or it reads as a number with a unit.
fn is_measure_value(value : String, data_type : String?) -> Bool {
  match data_type {
    Some("length") | Some("number") | Some("percentage") | Some("line-width") =>
      true
    Some(_) => false
    None => is_number_with_unit(value)
  }
}

///|
/// Upstream's `line-width` data type: every space-separated part is a length, a
/// number, or one of the three width keywords. It is what tells `border-[12px]`
/// (a width) from `border-[#0088cc]` (a color).
fn is_line_width_value(value : String) -> Bool {
  let parts = split_on_spaces(value)
  guard parts.length() > 0 else { return false }
  for part in parts {
    if part == "thin" || part == "medium" || part == "thick" {
      continue
    }
    guard is_number_with_unit(part) else { return false }
  }
  true
}

///|
fn is_number_with_unit(part : String) -> Bool {
  let mut index = 0
  if part.length() > 0 && (part[0] == '-' || part[0] == '+') {
    index += 1
  }
  let digits_start = index
  while index < part.length() &&
        ((part[index] >= '0' && part[index] <= '9') || part[index] == '.') {
    index += 1
  }
  guard index > digits_start else { return false }
  // Whatever follows the number must be a unit: letters, or a percent sign.
  while index < part.length() {
    let character = part[index]
    guard (character >= 'a' && character <= 'z') || character == '%' else {
      return false
    }
    index += 1
  }
  true
}

///|
fn split_on_spaces(value : String) -> Array[String] {
  let parts : Array[String] = []
  let buffer = StringBuilder()
  for character in value {
    if character == ' ' {
      if buffer.to_string() != "" {
        parts.push(buffer.to_string())
        buffer.reset()
      }
    } else {
      buffer.write_char(character)
    }
  }
  if buffer.to_string() != "" {
    parts.push(buffer.to_string())
  }
  parts
}

///|
fn border_width_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let entries : Array[(String, String, String, String)] = [
    (
      "border-x", "border-inline-style", "border-inline-width", "border-inline-color",
    ),
    (
      "border-y", "border-block-style", "border-block-width", "border-block-color",
    ),
    (
      "border-s", "border-inline-start-style", "border-inline-start-width", "border-inline-start-color",
    ),
    (
      "border-e", "border-inline-end-style", "border-inline-end-width", "border-inline-end-color",
    ),
    (
      "border-bs", "border-block-start-style", "border-block-start-width", "border-block-start-color",
    ),
    (
      "border-be", "border-block-end-style", "border-block-end-width", "border-block-end-color",
    ),
    ("border-t", "border-top-style", "border-top-width", "border-top-color"),
    (
      "border-r", "border-right-style", "border-right-width", "border-right-color",
    ),
    (
      "border-b", "border-bottom-style", "border-bottom-width", "border-bottom-color",
    ),
    ("border-l", "border-left-style", "border-left-width", "border-left-color"),
    ("border", "border-style", "border-width", "border-color"),
  ]
  for entry in entries {
    let (root, style_property, width_property, color_property) = entry
    let key = if name == root {
      ""
    } else {
      guard prefixed_value(name, root) is Some(key) else { continue }
      key
    }
    let width = fn(value : String) {
      Some([
        decl(style_property, "var(--tw-border-style)"),
        decl(width_property, value),
      ])
    }
    if key == "" {
      // A `--default-*` key is read for its value, not referenced as a
      // variable, so `border` inlines the width and leaves `:root` alone.
      return width(theme.get("--default-border-width").unwrap_or("1px"))
    }
    // An arbitrary value picks its own branch: an explicit `[length:…]` or
    // `[line-width:…]` is a width, anything else — including a bare `var()`,
    // which upstream infers nothing from — is a color.
    let (value, arbitrary, data_type) = unpack_functional_value(key)
    if arbitrary {
      return match data_type {
        Some("length") | Some("line-width") => width(value)
        Some(_) => Some([decl(color_property, value)])
        None =>
          if is_line_width_value(value) {
            width(value)
          } else {
            Some([decl(color_property, value)])
          }
      }
    }
    // A named value is a theme color first, then a border width, then a bare
    // pixel count.
    match selector_color_value(theme, key, ["--border-color", "--color"]) {
      Some(color) => return Some([decl(color_property, color)])
      None => ()
    }
    match theme_css_value(theme, "--border-width-\{key}") {
      Some(value) => return width(value)
      None => ()
    }
    if is_nonnegative_integer(key) {
      return width("\{key}px")
    }
    return None
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
/// The theme answers first: `--radius-full` in the theme beats the built-in
/// `full`, and a bare `rounded` is the `--radius` key itself.
fn radius_value(theme : Map[String, String], key : String) -> String? {
  if key == "" {
    return match theme_css_value(theme, "--radius") {
      Some(value) => Some(value)
      None => Some("0.25rem")
    }
  }
  match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match theme_css_value(theme, "--radius-\{key}") {
        Some(value) => Some(value)
        None =>
          match key {
            "none" => Some("0")
            "full" => Some("calc(infinity * 1px)")
            _ => None
          }
      }
  }
}

///|
/// Hoisted to a module-level constant (built once, read-only) — see
/// `directional_spacing_entries`.
let radius_entries : Array[(String, Array[String])] = [
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

///|
fn radius_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  // Fast-reject: every entry starts with "rounded", so skip the loop otherwise.
  guard name.has_prefix("rounded") else { return None }
  for entry in radius_entries {
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
  let value = if key == "" {
    Some(theme.get("--default-outline-width").unwrap_or("1px"))
  } else {
    match arbitrary_typed_value(key) {
      Some((value, data_type)) =>
        if is_measure_value(value, data_type) {
          Some(value)
        } else {
          None
        }
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
  guard value is Some(value) else { return None }
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
  // As with `decoration-*`, an arbitrary color here is a `stroke`, not a width.
  let value = match arbitrary_typed_value(key) {
    Some((value, data_type)) =>
      if is_measure_value(value, data_type) {
        Some(value)
      } else {
        None
      }
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
