///|
fn filter_composition(backdrop : Bool) -> String {
  if backdrop {
    "var(--tw-backdrop-blur,) var(--tw-backdrop-brightness,) var(--tw-backdrop-contrast,) var(--tw-backdrop-grayscale,) var(--tw-backdrop-hue-rotate,) var(--tw-backdrop-invert,) var(--tw-backdrop-opacity,) var(--tw-backdrop-saturate,) var(--tw-backdrop-sepia,)"
  } else {
    "var(--tw-blur,) var(--tw-brightness,) var(--tw-contrast,) var(--tw-grayscale,) var(--tw-hue-rotate,) var(--tw-invert,) var(--tw-saturate,) var(--tw-sepia,) var(--tw-drop-shadow,)"
  }
}

///|
fn filter_value(
  theme : Map[String, String],
  key : String,
  theme_namespace : String,
  default_value : String?,
  numeric_percent : Bool,
) -> String? {
  if key == "" {
    return default_value
  }
  match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match theme_css_value(theme, "\{theme_namespace}-\{key}") {
        Some(value) => Some(value)
        None =>
          if numeric_percent && is_spacing_number(key) {
            Some("\{key}%")
          } else {
            None
          }
      }
  }
}

///|
/// Hoisted to a module-level constant (built once, read-only) — see
/// `directional_spacing_entries`.
let filter_roots : Array[(String, String, String, String?, Bool)] = [
  ("blur", "--blur", "blur", Some("8px"), false),
  ("brightness", "--brightness", "brightness", None, true),
  ("contrast", "--contrast", "contrast", None, true),
  ("grayscale", "--grayscale", "grayscale", Some("100%"), true),
  ("hue-rotate", "--hue-rotate", "hue-rotate", None, false),
  ("invert", "--invert", "invert", Some("100%"), true),
  ("opacity", "--opacity", "opacity", None, true),
  ("saturate", "--saturate", "saturate", None, true),
  ("sepia", "--sepia", "sepia", Some("100%"), true),
]

///|
fn one_filter_utility(
  theme : Map[String, String],
  name : String,
  backdrop : Bool,
) -> Array[Declaration]? {
  // First-char / prefix fast-reject: skip the whole roots loop (and its per-entry
  // string building) for candidates that cannot possibly be a filter utility.
  // Safe because every `filter_roots` entry starts with one of these chars, and in
  // backdrop mode the candidate is always `backdrop-<root>`.
  if backdrop {
    guard name.has_prefix("backdrop-") else { return None }
  } else {
    guard name.length() > 0 else { return None }
    let c = name[0]
    guard c == 'b' ||
      c == 'c' ||
      c == 'g' ||
      c == 'h' ||
      c == 'i' ||
      c == 'o' ||
      c == 's' else {
      return None
    }
  }
  let prefix = if backdrop { "backdrop-" } else { "" }
  for entry in filter_roots {
    let (root, theme_namespace, function_name, default_value, percent) = entry
    if root == "opacity" && !backdrop {
      continue
    }
    let candidate_root = "\{prefix}\{root}"
    let key = if name == candidate_root {
      ""
    } else {
      guard prefixed_value(name, candidate_root) is Some(key) else { continue }
      key
    }
    guard filter_value(theme, key, theme_namespace, default_value, percent)
      is Some(value) else {
      continue
    }
    let property = if backdrop {
      "--tw-backdrop-\{root}"
    } else {
      "--tw-\{root}"
    }
    let declarations : Array[Declaration] = [
      decl(property, "\{function_name}(\{value})"),
    ]
    if backdrop {
      declarations.push(
        decl("-webkit-backdrop-filter", filter_composition(true)),
      )
      declarations.push(decl("backdrop-filter", filter_composition(true)))
    } else {
      declarations.push(decl("filter", filter_composition(false)))
    }
    return Some(declarations)
  }
  None
}

///|
fn filter_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  match name {
    "filter-none" => return Some([decl("filter", "none")])
    "backdrop-filter-none" =>
      return Some([
        decl("-webkit-backdrop-filter", "none"),
        decl("backdrop-filter", "none"),
      ])
    _ => ()
  }
  if name.has_prefix("drop-shadow-") {
    let key = name[12:].to_owned()
    match
      (theme.get("--color-\{key}"), theme_css_value(theme, "--color-\{key}")) {
      (Some(literal), Some(value)) =>
        return Some([
          {
            property: "--tw-drop-shadow-color",
            value: "color-mix(in oklab, \{value} var(--tw-drop-shadow-alpha), transparent)",
            fallback: Some(literal),
          },
          decl("--tw-drop-shadow", "var(--tw-drop-shadow-size)"),
        ])
      _ => ()
    }
    let raw_value = match arbitrary_value(key) {
      Some(value) => Some(value)
      None => theme.get("--drop-shadow-\{key}")
    }
    match raw_value {
      Some(value) => {
        let colored = shadow_value_with_color(value, "--tw-drop-shadow-color")
        return Some([
          decl("--tw-drop-shadow-size", "drop-shadow(\{colored})"),
          decl("--tw-drop-shadow", "drop-shadow(var(--drop-shadow-\{key}))"),
          decl("filter", filter_composition(false)),
        ])
      }
      None => ()
    }
  }
  match one_filter_utility(theme, name, true) {
    Some(value) => Some(value)
    None => one_filter_utility(theme, name, false)
  }
}

///|
fn touch_snap_utility(name : String) -> Array[Declaration]? {
  let touch = match name {
    "touch-auto" => Some([decl("touch-action", "auto")])
    "touch-none" => Some([decl("touch-action", "none")])
    "touch-manipulation" => Some([decl("touch-action", "manipulation")])
    "touch-pan-x" =>
      Some([
        decl("--tw-pan-x", "pan-x"),
        decl(
          "touch-action", "var(--tw-pan-x,) var(--tw-pan-y,) var(--tw-pinch-zoom,)",
        ),
      ])
    "touch-pan-y" =>
      Some([
        decl("--tw-pan-y", "pan-y"),
        decl(
          "touch-action", "var(--tw-pan-x,) var(--tw-pan-y,) var(--tw-pinch-zoom,)",
        ),
      ])
    "touch-pinch-zoom" =>
      Some([
        decl("--tw-pinch-zoom", "pinch-zoom"),
        decl(
          "touch-action", "var(--tw-pan-x,) var(--tw-pan-y,) var(--tw-pinch-zoom,)",
        ),
      ])
    _ => None
  }
  match touch {
    Some(value) => return Some(value)
    None => ()
  }
  match name {
    "snap-none" => Some([decl("scroll-snap-type", "none")])
    "snap-x" =>
      Some([decl("scroll-snap-type", "x var(--tw-scroll-snap-strictness)")])
    "snap-y" =>
      Some([decl("scroll-snap-type", "y var(--tw-scroll-snap-strictness)")])
    "snap-both" =>
      Some([decl("scroll-snap-type", "both var(--tw-scroll-snap-strictness)")])
    "snap-mandatory" => Some([decl("--tw-scroll-snap-strictness", "mandatory")])
    "snap-proximity" => Some([decl("--tw-scroll-snap-strictness", "proximity")])
    _ => None
  }
}

///|
fn transition_time_value(
  theme : Map[String, String],
  key : String,
  theme_namespace : String,
) -> String? {
  match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match theme_css_value(theme, "\{theme_namespace}-\{key}") {
        Some(value) => Some(value)
        None =>
          if is_nonnegative_integer(key) {
            Some("\{key}ms")
          } else {
            None
          }
      }
  }
}

///|
fn transition_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let all_properties = "color, background-color, border-color, outline-color, text-decoration-color, fill, stroke, --tw-gradient-from, --tw-gradient-via, --tw-gradient-to, opacity, box-shadow, transform, translate, scale, rotate, filter, -webkit-backdrop-filter, backdrop-filter, display, content-visibility, overlay, pointer-events"
  let color_properties = "color, background-color, border-color, outline-color, text-decoration-color, fill, stroke, --tw-gradient-from, --tw-gradient-via, --tw-gradient-to"
  let transition = match name {
    "transition-none" => Some([decl("transition-property", "none")])
    "transition-all" =>
      Some([
        decl("transition-property", "all"),
        decl("transition-timing-function", "var(--tw-ease, ease)"),
        decl("transition-duration", "var(--tw-duration, 0s)"),
      ])
    "transition-colors" =>
      Some([
        decl("transition-property", color_properties),
        decl("transition-timing-function", "var(--tw-ease, ease)"),
        decl("transition-duration", "var(--tw-duration, 0s)"),
      ])
    "transition" =>
      Some([
        decl("transition-property", all_properties),
        decl("transition-timing-function", "var(--tw-ease, ease)"),
        decl("transition-duration", "var(--tw-duration, 0s)"),
      ])
    _ => None
  }
  match transition {
    Some(value) => return Some(value)
    None => ()
  }
  if name.has_prefix("transition-") {
    let key = name[11:].to_owned()
    match arbitrary_value(key) {
      Some(value) =>
        return Some([
          decl("transition-property", value),
          decl("transition-timing-function", "var(--tw-ease, ease)"),
          decl("transition-duration", "var(--tw-duration, 0s)"),
        ])
      None => ()
    }
  }
  if name.has_prefix("duration-") {
    let key = name[9:].to_owned()
    return transition_time_value(theme, key, "--transition-duration").map(fn(
      value,
    ) {
      [decl("--tw-duration", value), decl("transition-duration", value)]
    })
  }
  if name.has_prefix("delay-") {
    let key = name[6:].to_owned()
    return transition_time_value(theme, key, "--transition-delay").map(fn(
      value,
    ) {
      [decl("transition-delay", value)]
    })
  }
  guard prefixed_value(name, "ease") is Some(key) else { return None }
  if key == "initial" {
    return Some([decl("--tw-ease", "initial")])
  }
  // A theme key wins over the static `linear` value.
  let value = match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match theme_css_value(theme, "--ease-\{key}") {
        Some(value) => Some(value)
        None => if key == "linear" { Some("linear") } else { None }
      }
  }
  value.map(fn(value) {
    [decl("--tw-ease", value), decl("transition-timing-function", value)]
  })
}

///|
fn stateful_filter_transition_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  match filter_utility(theme, name) {
    Some(value) => return Some(value)
    None => ()
  }
  match touch_snap_utility(name) {
    Some(value) => return Some(value)
    None => transition_utility(theme, name)
  }
}
