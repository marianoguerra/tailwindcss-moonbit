///|
fn typography_size_value(value : String) -> Bool {
  let units = [
    "px", "rem", "em", "ch", "ex", "cap", "ic", "lh", "rlh", "vw", "vh", "vmin",
    "vmax", "svw", "svh", "lvw", "lvh", "dvw", "dvh", "%",
  ]
  for unit in units {
    if value.has_suffix(unit) {
      return true
    }
  }
  value.has_prefix("calc(") ||
  value.has_prefix("clamp(") ||
  value.has_prefix("min(") ||
  value.has_prefix("max(") ||
  value.has_prefix("var(")
}

///|
fn typography_modifier_value(
  theme : Map[String, String],
  modifier : String,
) -> String? {
  match arbitrary_value(modifier) {
    Some(value) => Some(value)
    None =>
      match theme_css_value(theme, "--leading-\{modifier}") {
        Some(value) => Some(value)
        None => resolved_value(theme, modifier, "--leading", true)
      }
  }
}

///|
fn font_family_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  guard prefixed_value(name, "font") is Some(key) else { return None }
  match arbitrary_value(key) {
    Some(value) => Some([decl("font-family", value)])
    None =>
      match theme_css_value(theme, "--font-\{key}") {
        None => None
        Some(value) => {
          let declarations : Array[Declaration] = [decl("font-family", value)]
          match theme_css_value(theme, "--font-\{key}--font-feature-settings") {
            Some(settings) =>
              declarations.push(decl("font-feature-settings", settings))
            None => ()
          }
          match
            theme_css_value(theme, "--font-\{key}--font-variation-settings") {
            Some(settings) =>
              declarations.push(decl("font-variation-settings", settings))
            None => ()
          }
          Some(declarations)
        }
      }
  }
}

///|
fn font_size_utility(
  theme : Map[String, String],
  name : String,
  modifier : String?,
) -> Array[Declaration]? {
  guard prefixed_value(name, "text") is Some(key) else { return None }
  let (size, named_key) = match arbitrary_value(key) {
    Some(value) =>
      if typography_size_value(value) {
        (value, None)
      } else {
        return None
      }
    None =>
      match theme_css_value(theme, "--text-\{key}") {
        Some(value) => (value, Some(key))
        None => return None
      }
  }
  let declarations : Array[Declaration] = [decl("font-size", size)]
  match modifier {
    Some(modifier) =>
      match typography_modifier_value(theme, modifier) {
        Some(value) => declarations.push(decl("line-height", value))
        None => return None
      }
    None =>
      match named_key {
        Some(key) => {
          match theme_css_value(theme, "--text-\{key}--line-height") {
            Some(value) =>
              declarations.push(
                decl("line-height", "var(--tw-leading, \{value})"),
              )
            None => ()
          }
          match theme_css_value(theme, "--text-\{key}--letter-spacing") {
            Some(value) =>
              declarations.push(
                decl("letter-spacing", "var(--tw-tracking, \{value})"),
              )
            None => ()
          }
          match theme_css_value(theme, "--text-\{key}--font-weight") {
            Some(value) =>
              declarations.push(
                decl("font-weight", "var(--tw-font-weight, \{value})"),
              )
            None => ()
          }
        }
        None => ()
      }
  }
  Some(declarations)
}

///|
fn leading_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  guard prefixed_value(name, "leading") is Some(key) else { return None }
  let value = match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match theme_css_value(theme, "--leading-\{key}") {
        Some(value) => Some(value)
        None => resolved_value(theme, key, "--leading", true)
      }
  }
  value.map(fn(value) {
    [decl("--tw-leading", value), decl("line-height", value)]
  })
}

///|
fn tracking_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  guard prefixed_value(name, "tracking") is Some(key) else { return None }
  let value = match arbitrary_value(key) {
    Some(value) => Some(value)
    None => theme_css_value(theme, "--tracking-\{key}")
  }
  value.map(fn(value) {
    [decl("--tw-tracking", value), decl("letter-spacing", value)]
  })
}

///|
fn text_indent_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  guard prefixed_value(name, "indent") is Some(key) else { return None }
  let value = match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match theme_css_value(theme, "--text-indent-\{key}") {
        Some(value) => Some(value)
        None => resolved_value(theme, key, "--text-indent", true)
      }
  }
  value.map(fn(value) { [decl("text-indent", value)] })
}

///|
fn decoration_shape_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let styles = ["solid", "double", "dotted", "dashed", "wavy"]
  if name.has_prefix("decoration-") {
    let key = name[11:].to_owned()
    if styles.contains(key) {
      return Some([decl("text-decoration-style", key)])
    }
    if key == "auto" || key == "from-font" {
      return Some([decl("text-decoration-thickness", key)])
    }
    let value = match arbitrary_value(key) {
      Some(value) => Some(value)
      None =>
        match theme_css_value(theme, "--text-decoration-thickness-\{key}") {
          Some(value) => Some(value)
          None =>
            if is_nonnegative_integer(key) {
              Some("\{key}px")
            } else {
              None
            }
        }
    }
    return value.map(fn(value) { [decl("text-decoration-thickness", value)] })
  }
  guard name.has_prefix("underline-offset-") else { return None }
  let key = name[17:].to_owned()
  if key == "auto" {
    return Some([decl("text-underline-offset", "auto")])
  }
  let value = match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match theme_css_value(theme, "--text-underline-offset-\{key}") {
        Some(value) => Some(value)
        None =>
          if is_nonnegative_integer(key) {
            Some("\{key}px")
          } else {
            None
          }
      }
  }
  value.map(fn(value) { [decl("text-underline-offset", value)] })
}

///|
fn numeric_variant_utility(name : String) -> Array[Declaration]? {
  let property = match name {
    "ordinal" => Some(("--tw-ordinal", "ordinal"))
    "slashed-zero" => Some(("--tw-slashed-zero", "slashed-zero"))
    "lining-nums" => Some(("--tw-numeric-figure", "lining-nums"))
    "oldstyle-nums" => Some(("--tw-numeric-figure", "oldstyle-nums"))
    "proportional-nums" => Some(("--tw-numeric-spacing", "proportional-nums"))
    "tabular-nums" => Some(("--tw-numeric-spacing", "tabular-nums"))
    "diagonal-fractions" =>
      Some(("--tw-numeric-fraction", "diagonal-fractions"))
    "stacked-fractions" => Some(("--tw-numeric-fraction", "stacked-fractions"))
    "normal-nums" => return Some([decl("font-variant-numeric", "normal")])
    _ => None
  }
  guard property is Some((custom_property, value)) else { return None }
  Some([
    decl(custom_property, value),
    decl(
      "font-variant-numeric", "var(--tw-ordinal,) var(--tw-slashed-zero,) var(--tw-numeric-figure,) var(--tw-numeric-spacing,) var(--tw-numeric-fraction,)",
    ),
  ])
}

///|
fn typography_utility(
  theme : Map[String, String],
  name : String,
  modifier : String?,
) -> Array[Declaration]? {
  match font_family_utility(theme, name) {
    Some(value) => return Some(value)
    None => ()
  }
  match font_size_utility(theme, name, modifier) {
    Some(value) => return Some(value)
    None => ()
  }
  match leading_utility(theme, name) {
    Some(value) => return Some(value)
    None => ()
  }
  match tracking_utility(theme, name) {
    Some(value) => return Some(value)
    None => ()
  }
  match text_indent_utility(theme, name) {
    Some(value) => return Some(value)
    None => ()
  }
  match decoration_shape_utility(theme, name) {
    Some(value) => return Some(value)
    None => numeric_variant_utility(name)
  }
}
