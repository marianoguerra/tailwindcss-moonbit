///|
let theme_meta_prefix = "\u0000tailwind:"

///|
fn theme_meta(kind : String, name : String) -> String {
  "\{theme_meta_prefix}\{kind}:\{name}"
}

///|
fn default_theme() -> Map[String, String] {
  Map([])
}

///|
fn theme_prefix(theme : Map[String, String]) -> String? {
  theme.get(theme_meta("prefix", ""))
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
  if theme.contains(theme_meta("inline", logical_name)) {
    Some(value)
  } else {
    let variable = theme_variable_name(theme, logical_name)
    if theme.contains(theme_meta("reference", logical_name)) {
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
    theme.remove(theme_meta("inline", name))
    theme.remove(theme_meta("reference", name))
    theme.remove(theme_meta("static", name))
  }
}

///|
fn parse_theme(css : String) -> Map[String, String] raise CompileError {
  let theme = default_theme()
  collect_theme(parse_css(css), theme)
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
    let inline = params.split(" ").contains("inline")
    let reference = params.split(" ").contains("reference")
    let emit_all = params.split(" ").contains("static")
    for option in params.split(" ") {
      if option.has_prefix("prefix(") && option.has_suffix(")") {
        let prefix = option[7:option.length() - 1].to_owned()
        if prefix != "" {
          theme[theme_meta("prefix", "")] = prefix
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
          for kind in ["inline", "reference", "static"] {
            theme.remove(theme_meta(kind, name))
          }
          if inline {
            theme[theme_meta("inline", name)] = ""
          }
          if reference {
            theme[theme_meta("reference", name)] = ""
          }
          if emit_all {
            theme[theme_meta("static", name)] = ""
          }
        }
        AtRule(name="@keyframes", params=keyframe_name, ..) => {
          theme[theme_meta("keyframes", keyframe_name)] = render_css_nodes([
            child,
          ])
          if reference {
            theme[theme_meta("reference-keyframes", keyframe_name)] = ""
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
  let marker = theme_meta("keyframes", "")
  for name, value in theme {
    if !name.has_prefix(marker) {
      continue
    }
    let keyframe_name = name[marker.length():].to_owned()
    if theme.contains(theme_meta("reference-keyframes", keyframe_name)) {
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
