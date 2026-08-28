///|
/// Wrap the colour of each comma-separated shadow layer in
/// `var(<custom_property>, <colour>)` so `shadow-<color>` utilities can recolour
/// it. Handles multi-layer shadows and colours with internal spaces such as
/// `rgb(0 0 0 / 0.1)`.
/// Wraps a shadow's color in the alpha the modifier asked for. A literal from
/// the theme is rewritten in place with relative color syntax; `currentcolor`
/// has to go through `color-mix`, which the fallback pass then polyfills.
fn shadow_color_with_alpha(color : String, alpha : String?) -> String {
  match alpha {
    None => color
    Some(alpha) =>
      if color == "currentcolor" {
        "color-mix(in oklab, currentcolor \{alpha}, transparent)"
      } else {
        "oklab(from \{color} l a b / \{alpha})"
      }
  }
}

///|
fn shadow_value_with_color(
  value : String,
  custom_property : String,
  alpha : String?,
) -> String {
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
      // A trailing `var()` is taken as the color, as upstream does.
      ValueFunction(name, _) =>
        ["rgb", "rgba", "hsl", "hsla", "oklch", "oklab", "hwb", "color", "var"].contains(
          name,
        )
      ValueWord(word) => word.has_prefix("#")
      _ => false
    }
    if is_color {
      let rendered = shadow_color_with_alpha(render_value([nodes[index]]), alpha)
      nodes[index] = ValueWord("var(\{custom_property}, \{rendered})")
      render_value(nodes)
    } else {
      // A shadow written without a color still gets the slot, defaulting to
      // `currentcolor`, so `shadow-<color>` can fill it in later.
      let default_color = shadow_color_with_alpha("currentcolor", alpha)
      "\{layer} var(\{custom_property}, \{default_color})"
    }
  })
  wrapped.join(", ")
}

///|
/// A color for one of the shadow or ring utilities, resolved against its own
/// theme namespace before `--color`, with the three universal keywords.
fn shadow_color(
  theme : Map[String, String],
  theme_namespace : String,
  key : String,
) -> String? {
  match arbitrary_value(key) {
    Some(value) => return Some(value)
    None => ()
  }
  match keyword_color(key) {
    Some(value) => return Some(value)
    None => ()
  }
  for candidate_namespace in [theme_namespace, "--color"] {
    if theme_value(theme, candidate_namespace, key) is Some(_) {
      return theme_css_value(theme, "\{candidate_namespace}-\{key}")
    }
  }
  None
}

///|
/// The literal and the `var()` form of a shadow color, which the shadow
/// utilities need together: the literal becomes the `color-mix` fallback.
fn shadow_color_pair(
  theme : Map[String, String],
  theme_namespace : String,
  key : String,
) -> (String, String)? {
  // The universal keywords resolve to themselves, and are their own fallback.
  match keyword_color(key) {
    Some(value) => return Some((value, value))
    None => ()
  }
  for candidate_namespace in [theme_namespace, "--color"] {
    if theme.get("\{candidate_namespace}-\{key}") is Some(literal) &&
      theme_css_value(theme, "\{candidate_namespace}-\{key}") is Some(value) {
      return Some((literal, value))
    }
  }
  None
}

///|
fn shadow_ring_utility(
  theme : Map[String, String],
  name : String,
  modifier : String?,
) -> Array[Declaration]? {
  let shadow_stack = "var(--tw-inset-shadow), var(--tw-inset-ring-shadow), var(--tw-ring-offset-shadow), var(--tw-ring-shadow), var(--tw-shadow)"
  if name == "inset-ring" || name.has_prefix("inset-ring-") {
    let key = if name == "inset-ring" { "" } else { name[11:].to_owned() }
    let width = if key == "" {
      Some("1px")
    } else {
      match arbitrary_typed_value(key) {
        Some((value, data_type)) =>
          if is_measure_value(value, data_type) {
            Some(value)
          } else {
            None
          }
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
        match shadow_color(theme, "--ring-color", key) {
          Some(value) => return Some([decl("--tw-inset-ring-color", value)])
          None => return None
        }
    }
  }
  if name == "ring" || name.has_prefix("ring-") {
    let key = if name == "ring" { "" } else { name[5:].to_owned() }
    if key.has_prefix("offset-") {
      let offset_key = key[7:].to_owned()
      let width = match arbitrary_typed_value(offset_key) {
        Some((value, data_type)) =>
          if is_measure_value(value, data_type) {
            Some(value)
          } else {
            None
          }
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
          match shadow_color(theme, "--ring-offset-color", offset_key) {
            Some(value) => return Some([decl("--tw-ring-offset-color", value)])
            None => return None
          }
      }
    }
    let width = if key == "" {
      Some(theme.get("--default-ring-width").unwrap_or("1px"))
    } else {
      match arbitrary_typed_value(key) {
        Some((value, data_type)) =>
          if is_measure_value(value, data_type) {
            Some(value)
          } else {
            None
          }
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
        match shadow_color(theme, "--ring-color", key) {
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
  match shadow_color_pair(theme, "--box-shadow-color", key) {
    Some((literal, value)) => {
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
  // A modifier is the shadow's alpha, recorded in its own custom property and
  // folded into the color slot's default.
  let alpha = match modifier {
    Some(source) =>
      match alpha_modifier_value(theme, source) {
        Some(alpha) => Some(alpha)
        None => return None
      }
    None => None
  }
  value.map(fn(value) {
    let declarations : Array[Declaration] = []
    match alpha {
      Some(alpha) =>
        declarations.push(
          decl("\{color_property[:color_property.length() - 6]}-alpha", alpha),
        )
      None => ()
    }
    declarations.push(
      decl(property, shadow_value_with_color(value, color_property, alpha)),
    )
    declarations.push(decl("box-shadow", shadow_stack))
    declarations
  })
}

///|
fn text_shadow_utility(
  theme : Map[String, String],
  name : String,
  modifier : String?,
) -> Array[Declaration]? {
  guard prefixed_value(name, "text-shadow") is Some(key) else { return None }
  match shadow_color_pair(theme, "--text-shadow-color", key) {
    Some((literal, value)) =>
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
  let alpha = match modifier {
    Some(source) =>
      match alpha_modifier_value(theme, source) {
        Some(alpha) => Some(alpha)
        None => return None
      }
    None => None
  }
  value.map(fn(value) {
    let declarations : Array[Declaration] = []
    match alpha {
      Some(alpha) => declarations.push(decl("--tw-text-shadow-alpha", alpha))
      None => ()
    }
    declarations.push(
      decl(
        "text-shadow",
        shadow_value_with_color(value, "--tw-text-shadow-color", alpha),
      ),
    )
    declarations
  })
}

///|
fn gradient_color_or_position(
  theme : Map[String, String],
  key : String,
) -> (String, Bool)? {
  // A stop position is a percentage written as a plain number, so `from-25.0%`
  // and `from--5%` are not candidates.
  if key.has_suffix("%") {
    let number = key[:key.length() - 1].to_owned()
    return if is_canonical_number(number) { Some((key, true)) } else { None }
  }
  match arbitrary_typed_value(key) {
    // A typehint says which of the two a stop is; without one, a length-looking
    // value is a position and anything else is a color.
    Some((value, Some("length"))) | Some((value, Some("percentage"))) =>
      Some((value, true))
    Some((value, Some("color"))) => Some((value, false))
    Some((value, _)) =>
      Some(
        (
          value,
          value.has_suffix("%") ||
          value.has_suffix("px") ||
          value.has_suffix("rem"),
        ),
      )
    None =>
      match keyword_color(key) {
        Some(value) => Some((value, false))
        None =>
          match theme_css_value(theme, "--color-\{key}") {
            Some(value) => Some((value, false))
            None => None
          }
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
/// The second field reports whether the utility consumed the candidate's
/// modifier — the shadows take one as an alpha on their color slot.
fn stateful_effect_utility(
  theme : Map[String, String],
  name : String,
  modifier : String?,
) -> (Array[Declaration], Bool)? {
  // The alpha property is written exactly when a modifier was taken as a
  // shadow's alpha, so its presence is the answer.
  fn consumed(declarations : Array[Declaration]) -> Bool {
    declarations
    .iter()
    .any(fn(declaration) { declaration.property.has_suffix("-alpha") })
  }

  match shadow_ring_utility(theme, name, modifier) {
    Some(value) => return Some((value, consumed(value)))
    None => ()
  }
  match text_shadow_utility(theme, name, modifier) {
    Some(value) => return Some((value, consumed(value)))
    None => gradient_utility(theme, name).map(fn(value) { (value, false) })
  }
}
