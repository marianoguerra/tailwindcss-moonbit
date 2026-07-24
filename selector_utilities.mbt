///|
/// A utility that emits declarations inside a nested selector instead of the
/// candidate selector itself.
///
/// `nested_selector` uses `&` for the candidate selector, matching the upstream
/// `styleRule('&::placeholder', …)` form. `sort_key` mirrors the upstream
/// `--tw-sort` declaration: it replaces the declaration-derived property order
/// and still counts as one declaration.
priv struct SelectorUtility {
  nested_selector : String
  declarations : Array[Declaration]
  sort_key : String
}

///|
fn is_zero_length(value : String) -> Bool {
  if value == "" {
    return false
  }
  let mut end = value.length()
  while end > 0 {
    let c = value[end - 1]
    if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '%' {
      end -= 1
    } else {
      break
    }
  }
  let number = value[:end].to_owned()
  if number == "" {
    return false
  }
  let parsed = @string.parse_double(number) catch { _ => return false }
  parsed == 0.0
}

///|
/// Resolve the value of a `space-x-*` / `space-y-*` candidate.
///
/// Returns the resolved value plus whether it is a zero length, which upstream
/// collapses to a plain `0` instead of a `calc()` chain.
fn space_value(
  theme : Map[String, String],
  key : String,
  negative : Bool,
) -> (String, Bool)? {
  let value = match arbitrary_value(key) {
    Some(value) => value
    None =>
      match theme_value(theme, "--space", key) {
        Some(_) =>
          match theme_css_value(theme, "--space-\{key}") {
            Some(value) => value
            None => return None
          }
        None => {
          if key == "px" {
            return Some((if negative { "-1px" } else { "1px" }, false))
          }
          if !is_spacing_number(key) {
            return None
          }
          match numeric_spacing(theme, key) {
            Some(value) => value
            None => return None
          }
        }
      }
  }
  let zero = is_zero_length(value) || key == "0"
  if zero {
    return Some(("0", true))
  }
  Some((if negative { negate_value(value) } else { value }, false))
}

///|
/// Resolve the width of a `divide-x-*` / `divide-y-*` candidate.
fn divide_width_value(theme : Map[String, String], key : String) -> String? {
  if key == "" {
    return Some(
      theme_css_value(theme, "--default-border-width").unwrap_or("1px"),
    )
  }
  match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match theme_value(theme, "--divide-width", key) {
        Some(_) => theme_css_value(theme, "--divide-width-\{key}")
        None =>
          match theme_value(theme, "--border-width", key) {
            Some(_) => theme_css_value(theme, "--border-width-\{key}")
            None =>
              if is_nonnegative_integer(key) {
                Some("\{key}px")
              } else {
                None
              }
          }
      }
  }
}

///|
/// Resolve a color candidate value against an ordered list of theme namespaces.
fn selector_color_value(
  theme : Map[String, String],
  key : String,
  namespaces : ArrayView[String],
) -> String? {
  match arbitrary_value(key) {
    Some(value) => return Some(value)
    None => ()
  }
  match key {
    "inherit" => return Some("inherit")
    "current" => return Some("currentcolor")
    "transparent" => return Some("transparent")
    _ => ()
  }
  for theme_namespace in namespaces {
    if theme_value(theme, theme_namespace, key) is Some(_) {
      return theme_css_value(theme, "\{theme_namespace}-\{key}")
    }
  }
  None
}

///|
const DIVIDE_CHILD_SELECTOR : String = ":where(& > :not(:last-child))"

///|
fn space_reverse_utility(name : String) -> SelectorUtility? {
  let (axis, sort_key) = match name {
    "space-x-reverse" => ("x", "row-gap")
    "space-y-reverse" => ("y", "column-gap")
    _ => return None
  }
  Some({
    nested_selector: DIVIDE_CHILD_SELECTOR,
    declarations: [decl("--tw-space-\{axis}-reverse", "1")],
    sort_key,
  })
}

///|
fn divide_reverse_utility(name : String) -> SelectorUtility? {
  let axis = match name {
    "divide-x-reverse" => "x"
    "divide-y-reverse" => "y"
    _ => return None
  }
  Some({
    nested_selector: DIVIDE_CHILD_SELECTOR,
    declarations: [decl("--tw-divide-\{axis}-reverse", "1")],
    // Upstream omits `--tw-sort` here, so the custom property decides the order.
    sort_key: "",
  })
}

///|
fn divide_style_utility(name : String) -> SelectorUtility? {
  guard prefixed_value(name, "divide") is Some(style) else { return None }
  if !["solid", "dashed", "dotted", "double", "none"].contains(style) {
    return None
  }
  Some({
    nested_selector: DIVIDE_CHILD_SELECTOR,
    declarations: [
      decl("--tw-border-style", style),
      decl("border-style", style),
    ],
    sort_key: "divide-style",
  })
}

///|
fn space_utility(
  theme : Map[String, String],
  name : String,
  negative : Bool,
) -> SelectorUtility? {
  let (axis, start, end, sort_key) = if name.has_prefix("space-x-") {
    ("x", "margin-inline-start", "margin-inline-end", "row-gap")
  } else if name.has_prefix("space-y-") {
    ("y", "margin-block-start", "margin-block-end", "column-gap")
  } else {
    return None
  }
  let key = name["space-x-".length():].to_owned()
  guard space_value(theme, key, negative) is Some((value, zero)) else {
    return None
  }
  let reverse = "--tw-space-\{axis}-reverse"
  let declarations = if zero {
    [decl(reverse, "0"), decl(start, "0"), decl(end, "0")]
  } else {
    [
      decl(reverse, "0"),
      decl(start, "calc(\{value} * var(\{reverse}))"),
      decl(end, "calc(\{value} * calc(1 - var(\{reverse})))"),
    ]
  }
  Some({ nested_selector: DIVIDE_CHILD_SELECTOR, declarations, sort_key })
}

///|
fn divide_width_utility(
  theme : Map[String, String],
  name : String,
) -> SelectorUtility? {
  let (axis, key) = if name == "divide-x" {
    ("x", "")
  } else if name == "divide-y" {
    ("y", "")
  } else if name.has_prefix("divide-x-") {
    ("x", name["divide-x-".length():].to_owned())
  } else if name.has_prefix("divide-y-") {
    ("y", name["divide-y-".length():].to_owned())
  } else {
    return None
  }
  guard divide_width_value(theme, key) is Some(value) else { return None }
  let reverse = "--tw-divide-\{axis}-reverse"
  let declarations = if axis == "x" {
    [
      decl(reverse, "0"),
      decl("border-inline-style", "var(--tw-border-style)"),
      decl("border-inline-start-width", "calc(\{value} * var(\{reverse}))"),
      decl(
        "border-inline-end-width",
        "calc(\{value} * calc(1 - var(\{reverse})))",
      ),
    ]
  } else {
    [
      decl(reverse, "0"),
      decl("border-bottom-style", "var(--tw-border-style)"),
      decl("border-top-style", "var(--tw-border-style)"),
      decl("border-top-width", "calc(\{value} * var(\{reverse}))"),
      decl("border-bottom-width", "calc(\{value} * calc(1 - var(\{reverse})))"),
    ]
  }
  Some({
    nested_selector: DIVIDE_CHILD_SELECTOR,
    declarations,
    sort_key: "divide-\{axis}-width",
  })
}

///|
/// Compile a candidate that produces a nested selector rather than a flat
/// declaration list.
fn selector_utility(
  theme : Map[String, String],
  name : String,
  negative : Bool,
  modifier : String?,
) -> SelectorUtility? {
  if negative && !name.has_prefix("space-") {
    return None
  }
  if modifier is Some(_) &&
    !(name.has_prefix("divide-") || name.has_prefix("placeholder-")) {
    return None
  }
  match space_reverse_utility(name) {
    Some(utility) => return Some(utility)
    None => ()
  }
  match divide_reverse_utility(name) {
    Some(utility) => return Some(utility)
    None => ()
  }
  match divide_style_utility(name) {
    Some(utility) => return Some(utility)
    None => ()
  }
  match space_utility(theme, name, negative) {
    Some(utility) => return Some(utility)
    None => ()
  }
  match divide_width_utility(theme, name) {
    Some(utility) => return Some(utility)
    None => ()
  }
  if prefixed_value(name, "divide") is Some(key) {
    if selector_color_value(theme, key, [
        "--divide-color", "--border-color", "--color",
      ])
      is Some(color) {
      return Some({
        nested_selector: DIVIDE_CHILD_SELECTOR,
        declarations: apply_candidate_value(
          theme,
          [decl("border-color", color)],
          false,
          modifier,
        ),
        sort_key: "divide-color",
      })
    }
  }
  if prefixed_value(name, "placeholder") is Some(key) {
    if selector_color_value(theme, key, ["--placeholder-color", "--color"])
      is Some(color) {
      return Some({
        nested_selector: "&::placeholder",
        declarations: apply_candidate_value(
          theme,
          [decl("color", color)],
          false,
          modifier,
        ),
        sort_key: "placeholder-color",
      })
    }
  }
  None
}
