///|
/// Wrap the colour of each comma-separated shadow layer in
/// `var(<custom_property>, <colour>)` so `shadow-<color>` utilities can recolour
/// it. Handles multi-layer shadows and colours with internal spaces such as
/// `rgb(0 0 0 / 0.1)`.
fn shadow_value_with_color(value : String, custom_property : String) -> String {
  let layers = split_function_arguments(value)
  if layers.length() == 0 {
    return value
  }
  let wrapped = layers.map(fn(layer) {
    let nodes = parse_value(layer)
    // The colour is the last non-separator token in the layer.
    let mut index = -1
    for i, node in nodes {
      if !(node is ValueSeparator(_)) {
        index = i
      }
    }
    if index < 0 {
      return layer
    }
    let is_color = match nodes[index] {
      ValueFunction(name, _) =>
        ["rgb", "rgba", "hsl", "hsla", "oklch", "oklab", "hwb", "color"].contains(
          name,
        )
      ValueWord(word) => word.has_prefix("#")
      _ => false
    }
    if is_color {
      let rendered = render_value([nodes[index]])
      nodes[index] = ValueWord("var(\{custom_property}, \{rendered})")
      render_value(nodes)
    } else {
      layer
    }
  })
  wrapped.join(", ")
}

///|
fn shadow_ring_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let shadow_stack = "var(--tw-inset-shadow), var(--tw-inset-ring-shadow), var(--tw-ring-offset-shadow), var(--tw-ring-shadow), var(--tw-shadow)"
  if name == "inset-ring" || name.has_prefix("inset-ring-") {
    let key = if name == "inset-ring" { "" } else { name[11:].to_owned() }
    let width = if key == "" {
      Some("1px")
    } else {
      match arbitrary_value(key) {
        Some(value) => Some(value)
        None =>
          if is_nonnegative_integer(key) {
            Some("\{key}px")
          } else {
            theme_css_value(theme, "--inset-ring-width-\{key}")
          }
      }
    }
    match width {
      Some(value) =>
        return Some([
          decl(
            "--tw-inset-ring-shadow",
            "inset 0 0 0 \{value} var(--tw-inset-ring-color, currentcolor)",
          ),
          decl("box-shadow", shadow_stack),
        ])
      None =>
        match theme_css_value(theme, "--color-\{key}") {
          Some(value) => return Some([decl("--tw-inset-ring-color", value)])
          None => return None
        }
    }
  }
  if name == "ring" || name.has_prefix("ring-") {
    let key = if name == "ring" { "" } else { name[5:].to_owned() }
    if key.has_prefix("offset-") {
      let offset_key = key[7:].to_owned()
      let width = match arbitrary_value(offset_key) {
        Some(value) => Some(value)
        None =>
          if is_nonnegative_integer(offset_key) {
            Some("\{offset_key}px")
          } else {
            theme_css_value(theme, "--ring-offset-width-\{offset_key}")
          }
      }
      match width {
        Some(value) =>
          return Some([
            decl("--tw-ring-offset-width", value),
            decl(
              "--tw-ring-offset-shadow", "var(--tw-ring-inset,) 0 0 0 var(--tw-ring-offset-width) var(--tw-ring-offset-color)",
            ),
          ])
        None =>
          match theme_css_value(theme, "--color-\{offset_key}") {
            Some(value) => return Some([decl("--tw-ring-offset-color", value)])
            None => return None
          }
      }
    }
    let width = if key == "" {
      Some("1px")
    } else {
      match arbitrary_value(key) {
        Some(value) => Some(value)
        None =>
          if is_nonnegative_integer(key) {
            Some("\{key}px")
          } else {
            theme_css_value(theme, "--ring-width-\{key}")
          }
      }
    }
    match width {
      Some(value) =>
        return Some([
          decl(
            "--tw-ring-shadow",
            "var(--tw-ring-inset,) 0 0 0 calc(\{value} + var(--tw-ring-offset-width)) var(--tw-ring-color, currentcolor)",
          ),
          decl("box-shadow", shadow_stack),
        ])
      None =>
        match theme_css_value(theme, "--color-\{key}") {
          Some(value) => return Some([decl("--tw-ring-color", value)])
          None => return None
        }
    }
  }
  let (root, theme_namespace, property, color_property) = if name.has_prefix(
      "inset-shadow-",
    ) {
    (
      "inset-shadow", "--inset-shadow", "--tw-inset-shadow", "--tw-inset-shadow-color",
    )
  } else if name.has_prefix("shadow-") || name == "shadow" {
    ("shadow", "--shadow", "--tw-shadow", "--tw-shadow-color")
  } else {
    return None
  }
  let key = if name == root {
    ""
  } else {
    guard prefixed_value(name, root) is Some(key) else { return None }
    key
  }
  if key == "none" {
    return Some([decl(property, "0 0 #0000"), decl("box-shadow", shadow_stack)])
  }
  match
    (theme.get("--color-\{key}"), theme_css_value(theme, "--color-\{key}")) {
    (Some(literal), Some(value)) => {
      let alpha_property = "\{color_property[:color_property.length() - 6]}-alpha"
      return Some([
        {
          property: color_property,
          value: "color-mix(in oklab, \{value} var(\{alpha_property}), transparent)",
          fallback: Some(literal),
        },
      ])
    }
    _ => ()
  }
  let value = if key == "" {
    theme.get(theme_namespace)
  } else {
    match arbitrary_value(key) {
      Some(value) => Some(value)
      None => theme.get("\{theme_namespace}-\{key}")
    }
  }
  value.map(fn(value) {
    [
      decl(property, shadow_value_with_color(value, color_property)),
      decl("box-shadow", shadow_stack),
    ]
  })
}

///|
fn text_shadow_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  guard prefixed_value(name, "text-shadow") is Some(key) else { return None }
  match
    (theme.get("--color-\{key}"), theme_css_value(theme, "--color-\{key}")) {
    (Some(literal), Some(value)) =>
      return Some([
        {
          property: "--tw-text-shadow-color",
          value: "color-mix(in oklab, \{value} var(--tw-text-shadow-alpha), transparent)",
          fallback: Some(literal),
        },
      ])
    _ => ()
  }
  let value = match arbitrary_value(key) {
    Some(value) => Some(value)
    None => theme.get("--text-shadow-\{key}")
  }
  value.map(fn(value) {
    [
      decl(
        "text-shadow",
        shadow_value_with_color(value, "--tw-text-shadow-color"),
      ),
    ]
  })
}

///|
fn gradient_color_or_position(
  theme : Map[String, String],
  key : String,
) -> (String, Bool)? {
  if key.has_suffix("%") {
    return Some((key, true))
  }
  match arbitrary_value(key) {
    Some(value) =>
      Some(
        (
          value,
          value.has_suffix("%") ||
          value.has_suffix("px") ||
          value.has_suffix("rem"),
        ),
      )
    None =>
      match theme_css_value(theme, "--color-\{key}") {
        Some(value) => Some((value, false))
        None => None
      }
  }
}

///|
fn gradient_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let directions : Array[(String, String)] = [
    ("bg-linear-to-t", "to top"),
    ("bg-linear-to-tr", "to top right"),
    ("bg-linear-to-r", "to right"),
    ("bg-linear-to-br", "to bottom right"),
    ("bg-linear-to-b", "to bottom"),
    ("bg-linear-to-bl", "to bottom left"),
    ("bg-linear-to-l", "to left"),
    ("bg-linear-to-tl", "to top left"),
  ]
  for entry in directions {
    let (candidate, direction) = entry
    if name == candidate {
      return Some([
        decl("--tw-gradient-position", direction),
        decl("background-image", "linear-gradient(var(--tw-gradient-stops))"),
      ])
    }
  }
  if name.has_prefix("bg-linear-") {
    let key = name[10:].to_owned()
    match arbitrary_value(key) {
      Some(value) =>
        return Some([
          decl("--tw-gradient-position", value),
          decl(
            "background-image",
            "linear-gradient(var(--tw-gradient-stops,\{value}))",
          ),
        ])
      None => ()
    }
  }
  let (root, color_property, position_property) = if name.has_prefix("from-") {
    ("from", "--tw-gradient-from", "--tw-gradient-from-position")
  } else if name.has_prefix("via-") {
    ("via", "--tw-gradient-via", "--tw-gradient-via-position")
  } else if name.has_prefix("to-") {
    ("to", "--tw-gradient-to", "--tw-gradient-to-position")
  } else {
    return None
  }
  guard prefixed_value(name, root) is Some(key) else { return None }
  guard gradient_color_or_position(theme, key) is Some((value, position)) else {
    return None
  }
  if position {
    return Some([decl(position_property, value)])
  }
  let standard_stops = "var(--tw-gradient-via-stops, var(--tw-gradient-position), var(--tw-gradient-from) var(--tw-gradient-from-position), var(--tw-gradient-to) var(--tw-gradient-to-position))"
  match root {
    "via" =>
      Some([
        decl(color_property, value),
        decl(
          "--tw-gradient-via-stops", "var(--tw-gradient-position), var(--tw-gradient-from) var(--tw-gradient-from-position), var(--tw-gradient-via) var(--tw-gradient-via-position), var(--tw-gradient-to) var(--tw-gradient-to-position)",
        ),
        decl("--tw-gradient-stops", "var(--tw-gradient-via-stops)"),
      ])
    _ =>
      Some([
        decl(color_property, value),
        decl("--tw-gradient-stops", standard_stops),
      ])
  }
}

///|
fn stateful_effect_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  match shadow_ring_utility(theme, name) {
    Some(value) => return Some(value)
    None => ()
  }
  match text_shadow_utility(theme, name) {
    Some(value) => return Some(value)
    None => gradient_utility(theme, name)
  }
}
