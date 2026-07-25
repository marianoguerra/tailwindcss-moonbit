///|
let theme_meta_prefix = "\u0000tailwind:"

///|
/// Theme options live in the same map as theme values, under keys that cannot
/// collide with a custom property. Building those keys through `theme_meta`
/// interpolates a string on every probe — on a path that runs for every theme
/// variable on every build, which the profiler put at ~14% of a `stress`
/// compile. Each kind's prefix is a constant, so a key is one concatenation.
let theme_meta_inline_prefix = "\u0000tailwind:inline:"

///|
let theme_meta_reference_prefix = "\u0000tailwind:reference:"

///|
let theme_meta_static_prefix = "\u0000tailwind:static:"

///|
let theme_meta_keyframes_prefix = "\u0000tailwind:keyframes:"

///|
let theme_meta_reference_keyframes_prefix = "\u0000tailwind:reference-keyframes:"

///|
/// The variable prefix is a single entry, so its key is fixed outright.
let theme_meta_prefix_key = "\u0000tailwind:prefix:"

///|
fn default_theme() -> Map[String, String] {
  Map([])
}

///|
fn theme_prefix(theme : Map[String, String]) -> String? {
  theme.get(theme_meta_prefix_key)
}

///|
fn theme_variable_name(
  theme : Map[String, String],
  logical_name : String,
) -> String {
  match theme_prefix(theme) {
    Some(prefix) if logical_name.has_prefix("--") =>
      "--\{prefix}-\{logical_name[2:]}"
    _ => logical_name
  }
}

///|
fn theme_css_value(
  theme : Map[String, String],
  logical_name : String,
) -> String? {
  guard theme.get(logical_name) is Some(value) else { return None }
  if theme.contains(theme_meta_inline_prefix + logical_name) {
    Some(value)
  } else {
    let variable = theme_variable_name(theme, logical_name)
    if theme.contains(theme_meta_reference_prefix + logical_name) {
      Some("var(\{variable}, \{value})")
    } else {
      Some("var(\{variable})")
    }
  }
}

///|
fn remove_theme_namespace(
  theme : Map[String, String],
  namespace_prefix : String,
) -> Unit {
  let removed : Array[String] = []
  for name, _ in theme {
    if name.has_prefix(namespace_prefix) {
      removed.push(name)
    }
  }
  for name in removed {
    theme.remove(name)
    theme.remove(theme_meta_inline_prefix + name)
    theme.remove(theme_meta_reference_prefix + name)
    theme.remove(theme_meta_static_prefix + name)
  }
}

///|
fn parse_theme(nodes : ArrayView[CssNode]) -> Map[String, String] {
  let theme = default_theme()
  collect_theme(nodes, theme)
  theme
}

///|
/// Collect `@theme` blocks at any depth, since imports may wrap them in layer,
/// media or supports conditions.
fn collect_theme(
  nodes : ArrayView[CssNode],
  theme : Map[String, String],
) -> Unit {
  for node in nodes {
    guard node is AtRule(name="@theme", params~, nodes=Some(children), ..) else {
      match node {
        Rule(nodes=inner, ..)
        | AtRule(nodes=Some(inner), ..)
        | Context(nodes=inner, ..) => collect_theme(inner, theme)
        _ => ()
      }
      continue
    }
    let options = params.split(" ").to_array()
    let inline = options.contains("inline")
    let reference = options.contains("reference")
    let emit_all = options.contains("static")
    for option in options {
      if option.has_prefix("prefix(") && option.has_suffix(")") {
        let prefix = option[7:option.length() - 1].to_owned()
        if prefix != "" {
          theme[theme_meta_prefix_key] = prefix
        }
      }
    }
    for child in children {
      match child {
        Declaration(name~, value~, ..) if name.has_prefix("--") => {
          if name.has_suffix("-*") && trim(value) == "initial" {
            remove_theme_namespace(theme, name[:name.length() - 1].to_owned())
            continue
          }
          theme[name] = value
          theme.remove(theme_meta_inline_prefix + name)
          theme.remove(theme_meta_reference_prefix + name)
          theme.remove(theme_meta_static_prefix + name)
          if inline {
            theme[theme_meta_inline_prefix + name] = ""
          }
          if reference {
            theme[theme_meta_reference_prefix + name] = ""
          }
          if emit_all {
            theme[theme_meta_static_prefix + name] = ""
          }
        }
        AtRule(name="@keyframes", params=keyframe_name, ..) => {
          theme[theme_meta_keyframes_prefix + keyframe_name] = render_css_nodes([
              child,
            ],
          )
          if reference {
            theme[theme_meta_reference_keyframes_prefix + keyframe_name] = ""
          }
        }
        _ => ()
      }
    }
  }
}

///|
fn render_used_keyframes(
  theme : Map[String, String],
  generated_css : String,
) -> String {
  let output = StringBuilder()
  let marker = theme_meta_keyframes_prefix
  for name, value in theme {
    if !name.has_prefix(marker) {
      continue
    }
    let keyframe_name = name[marker.length():].to_owned()
    if theme.contains(theme_meta_reference_keyframes_prefix + keyframe_name) {
      continue
    }
    let mut used = false
    for token_name, token_value in theme {
      if token_name.has_prefix("--animate-") &&
        trim(token_value).has_prefix(keyframe_name) {
        match theme_css_value(theme, token_name) {
          Some(css_value) =>
            if generated_css.contains(css_value) {
              used = true
            }
          None => ()
        }
      }
    }
    if used {
      output.write_string(value)
    }
  }
  output.to_string()
}

///|
fn theme_value(
  theme : Map[String, String],
  theme_namespace : String,
  key : String,
) -> String? {
  theme.get("\{theme_namespace}-\{key}")
}

///|
/// Resolve compile-time functions (`--theme()`, `--spacing()`, `theme()`,
/// `--alpha()`) that appear inside theme values themselves, so the emitted
/// `:root` declarations never carry an unresolved compile-time call.
fn resolve_theme_value_functions(
  theme : Map[String, String],
) -> Unit raise CompileError {
  let updates : Array[(String, String)] = []
  for name, value in theme {
    if name.has_prefix(theme_meta_prefix) {
      continue
    }
    if !(value.contains("--theme(") ||
      value.contains("--spacing(") ||
      value.contains("--alpha(") ||
      value.contains("theme(")) {
      continue
    }
    let (resolved, changed) = substitute_value_functions(
      value,
      theme,
      inline_theme=false,
    )
    if changed {
      updates.push((name, resolved))
    }
  }
  for update in updates {
    theme[update.0] = update.1
  }
}
