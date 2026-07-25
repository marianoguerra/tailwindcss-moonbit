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
  // A `@keyframes` block is emitted when some `--animate-*` token that names it
  // reaches the generated CSS. That used to be decided by walking the *whole*
  // theme again for every keyframe — so a full import paid (keyframes x theme
  // size) prefix tests — and by recomputing `theme_css_value` plus a fresh
  // whole-output search for every (keyframe, token) pair that matched.
  //
  // One pass collects both sides instead, and each token's search runs at most
  // once. The searches stay lazy: a token is only looked for once a keyframe
  // actually names it, which is what the old inner loop did.
  let marker = theme_meta_keyframes_prefix
  let keyframe_names : Array[String] = []
  let keyframe_values : Array[String] = []
  let animate_tokens : Array[String] = []
  let animate_values : Array[String] = []
  for name, value in theme {
    if name.has_prefix(marker) {
      let keyframe_name = name[marker.length():].to_owned()
      if theme.contains(theme_meta_reference_keyframes_prefix + keyframe_name) {
        continue
      }
      keyframe_names.push(keyframe_name)
      keyframe_values.push(value)
    } else if name.has_prefix("--animate-") {
      animate_tokens.push(name)
      animate_values.push(trim(value))
    }
  }
  if keyframe_names.is_empty() {
    return ""
  }
  // Per token: -1 not searched for yet, 0 absent, 1 present.
  let animate_state = Array::make(animate_tokens.length(), -1)
  let output = StringBuilder()
  for index, keyframe_name in keyframe_names {
    let mut used = false
    for token in 0..<animate_tokens.length() {
      if !animate_values[token].has_prefix(keyframe_name) {
        continue
      }
      if animate_state[token] < 0 {
        animate_state[token] = match
          theme_css_value(theme, animate_tokens[token]) {
          Some(css_value) =>
            if generated_css.contains(css_value) {
              1
            } else {
              0
            }
          None => 0
        }
      }
      if animate_state[token] == 1 {
        used = true
        break
      }
    }
    if used {
      output.write_string(keyframe_values[index])
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
