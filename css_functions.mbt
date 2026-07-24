///|
fn split_function_arguments(input : String) -> Array[String] {
  let arguments : Array[String] = []
  let mut start = 0
  let mut depth = 0
  for i in 0..<input.length() {
    match input[i] {
      '(' | '[' => depth += 1
      ')' | ']' => depth -= 1
      ',' =>
        if depth == 0 {
          arguments.push(trim(input[start:i].to_owned()))
          start = i + 1
        }
      _ => ()
    }
  }
  arguments.push(trim(input[start:].to_owned()))
  arguments
}

///|
fn find_function_end(input : String, open : Int) -> Int raise CompileError {
  let mut depth = 1
  let mut quote : UInt16? = None
  for i = open + 1; i < input.length(); i = i + 1 {
    let c = input[i]
    match quote {
      Some(q) => if c == q && (i == 0 || input[i - 1] != '\\') { quote = None }
      None =>
        match c {
          '\'' | '"' => quote = Some(c)
          '(' => depth += 1
          ')' => {
            depth -= 1
            if depth == 0 {
              return i
            }
          }
          _ => ()
        }
    }
  }
  raise InvalidCss("Unclosed CSS function")
}

///|
fn resolve_theme_function(
  theme : Map[String, String],
  raw_path : String,
  fallback : ArrayView[String],
  inline : Bool,
) -> String raise CompileError {
  let path = trim(raw_path)
  let (path, force_inline) = if path.has_suffix(" inline") {
    (trim(path[:path.length() - 7].to_owned()), true)
  } else {
    (path, false)
  }
  if !path.has_prefix("--") {
    raise InvalidCss("--theme() requires a CSS theme variable")
  }
  match theme.get(path) {
    Some(value) =>
      if inline || force_inline {
        value
      } else if fallback.is_empty() || trim(fallback.join(", ")) == "initial" {
        // `var(x, initial)` is equivalent to `var(x)`; upstream drops the
        // redundant `initial` fallback.
        "var(\{path})"
      } else {
        "var(\{path}, \{fallback.join(", ")})"
      }
    None =>
      if fallback.is_empty() {
        raise InvalidCss("Could not resolve theme value: \{path}")
      } else {
        fallback.join(", ")
      }
  }
}

///|
fn legacy_theme_key(path : String) -> String {
  let unquoted = if path.length() >= 2 &&
    (
      (path.has_prefix("\"") && path.has_suffix("\"")) ||
      (path.has_prefix("'") && path.has_suffix("'"))
    ) {
    path[1:path.length() - 1].to_owned()
  } else {
    path
  }
  replace_all(replace_all(replace_all(unquoted, ".", "-"), "[", "-"), "]", "")
}

///|
fn evaluate_css_function(
  name : String,
  content : String,
  theme : Map[String, String],
  inline_theme : Bool,
) -> String raise CompileError {
  let arguments = split_function_arguments(content)
  match name {
    "--spacing" => {
      if arguments.length() != 1 || arguments[0] == "" {
        raise InvalidCss("--spacing() requires one argument")
      }
      guard theme.get("--spacing") is Some(_) else {
        raise InvalidCss("--spacing() requires --spacing in the theme")
      }
      match arguments[0] {
        "0" => "0px"
        "1" => "var(--spacing)"
        value => "calc(var(--spacing) * \{value})"
      }
    }
    "--alpha" => {
      if arguments.length() != 1 {
        raise InvalidCss("--alpha() requires one color/alpha argument")
      }
      guard arguments[0].split_once("/") is Some((color, alpha)) else {
        raise InvalidCss("--alpha() requires `color / alpha`")
      }
      "color-mix(in oklab, \{trim(color.to_owned())} \{trim(alpha.to_owned())}, transparent)"
    }
    "--theme" => {
      if arguments.is_empty() {
        raise InvalidCss("--theme() requires a theme variable")
      }
      resolve_theme_function(theme, arguments[0], arguments[1:], inline_theme)
    }
    "theme" => {
      if arguments.is_empty() {
        raise InvalidCss("theme() requires a theme path")
      }
      let key = legacy_theme_key(arguments[0])
      let variable = if key.has_prefix("--") { key } else { "--\{key}" }
      resolve_theme_function(theme, variable, arguments[1:], inline_theme)
    }
    _ => content
  }
}

///|
fn substitute_value_functions(
  input : String,
  theme : Map[String, String],
  inline_theme~ : Bool,
) -> (String, Bool) raise CompileError {
  let ast = parse_value(input)
  let (ast, changed) = substitute_value_ast(ast, theme, inline_theme)
  (render_value(ast), changed)
}

///|
fn substitute_value_ast(
  nodes : ArrayView[ValueNode],
  theme : Map[String, String],
  inline_theme : Bool,
) -> (Array[ValueNode], Bool) raise CompileError {
  let output : Array[ValueNode] = []
  let mut changed = false
  for node in nodes {
    match node {
      ValueFunction(name, children) => {
        let (children, child_changed) = substitute_value_ast(
          children, theme, inline_theme,
        )
        changed = changed || child_changed
        if name == "--alpha" ||
          name == "--spacing" ||
          name == "--theme" ||
          name == "theme" {
          output.push(
            ValueWord(
              evaluate_css_function(
                name,
                render_value(children),
                theme,
                inline_theme,
              ),
            ),
          )
          changed = true
        } else {
          output.push(ValueFunction(name, children))
        }
      }
      _ => output.push(node)
    }
  }
  (output, changed)
}

///|
fn substitute_css_functions(
  nodes : ArrayView[CssNode],
  theme : Map[String, String],
) -> (Array[CssNode], Bool) raise CompileError {
  let output : Array[CssNode] = []
  let mut changed = false
  for node in nodes {
    match node {
      Declaration(name~, value~, important~, span~) => {
        let (value, did_change) = substitute_value_functions(
          value,
          theme,
          inline_theme=false,
        )
        changed = changed || did_change
        output.push(Declaration(name~, value~, important~, span~))
      }
      Rule(selector~, nodes~, span~) => {
        let (children, child_changed) = substitute_css_functions(nodes, theme)
        changed = changed || child_changed
        output.push(Rule(selector~, nodes=children, span~))
      }
      AtRule(name~, params~, nodes~, span~) => {
        let conditional = name == "@media" ||
          name == "@custom-media" ||
          name == "@container" ||
          name == "@supports"
        let (params, params_changed) = if conditional {
          substitute_value_functions(params, theme, inline_theme=true)
        } else {
          (params, false)
        }
        let children = match nodes {
          Some(children) => {
            let (children, child_changed) = substitute_css_functions(
              children, theme,
            )
            changed = changed || child_changed
            Some(children)
          }
          None => None
        }
        changed = changed || params_changed
        output.push(AtRule(name~, params~, nodes=children, span~))
      }
      Context(values~, nodes=children, span~) => {
        let (inner, inner_changed) = substitute_css_functions(children, theme)
        changed = changed || inner_changed
        output.push(Context(values~, nodes=inner, span~))
      }
      Comment(..) | AtRoot(..) => output.push(node)
    }
  }
  (output, changed)
}
