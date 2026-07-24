///|
fn is_ascii_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_nonnegative_integer(input : String) -> Bool {
  if input == "" {
    return false
  }
  for c in input {
    if !is_ascii_digit(c) {
      return false
    }
  }
  true
}

///|
fn is_spacing_number(input : String) -> Bool {
  let parsed = @string.parse_double(input) catch { _ => return false }
  if parsed < 0.0 {
    return false
  }
  let quarters = parsed * 4.0
  quarters == quarters.floor()
}

///|
fn normalize_ratio(input : String, spaced : Bool) -> String? {
  guard input.split_once("/") is Some((left, right)) else { return None }
  let left = trim(left.to_owned())
  let right = trim(right.to_owned())
  if !is_nonnegative_integer(left) ||
    left == "0" ||
    !is_nonnegative_integer(right) ||
    right == "0" {
    return None
  }
  Some(if spaced { "\{left} / \{right}" } else { "\{left}/\{right}" })
}

///|
fn unpack_functional_value(raw : String) -> (String, Bool, String?) {
  if raw.length() >= 2 && raw.has_prefix("[") && raw.has_suffix("]") {
    let inner = raw[1:raw.length() - 1].to_owned()
    match inner.split_once(":") {
      Some((data_type, value)) =>
        (decode_arbitrary(value.to_owned()), true, Some(data_type.to_owned()))
      None => (decode_arbitrary(inner), true, None)
    }
  } else if raw.length() >= 4 && raw.has_prefix("(--") && raw.has_suffix(")") {
    ("var(\{raw[1:raw.length() - 1].to_owned()})", true, None)
  } else if raw.length() >= 5 && raw.has_prefix("(") && raw.has_suffix(")") {
    let inner = raw[1:raw.length() - 1].to_owned()
    match inner.split_once(":") {
      Some((data_type, variable)) =>
        if variable.has_prefix("--") {
          ("var(\{variable.to_owned()})", true, Some(data_type.to_owned()))
        } else {
          (raw, false, None)
        }
      None => (raw, false, None)
    }
  } else {
    (raw, false, None)
  }
}

///|
fn functional_candidate_value(
  root : String,
  candidate : String,
) -> (String?, Bool, String?)? {
  if candidate == root {
    return Some((None, false, None))
  }
  let prefix = "\{root}-"
  guard candidate.has_prefix(prefix) else { return None }
  let raw = candidate[prefix.length():].to_owned()
  if raw == "" {
    None
  } else {
    let (value, arbitrary, data_type) = unpack_functional_value(raw)
    Some((Some(value), arbitrary, data_type))
  }
}

///|
fn resolve_functional_argument(
  argument : String,
  value : String?,
  arbitrary : Bool,
  value_data_type : String?,
  theme : Map[String, String],
) -> String? {
  let argument = replace_all(replace_all(trim(argument), "\\*", "*"), " ", "")
  match value {
    None =>
      if argument.has_prefix("--default(") && argument.has_suffix(")") {
        return Some(trim(argument[10:argument.length() - 1].to_owned()))
      } else {
        return None
      }
    Some(_) => ()
  }
  guard value is Some(value) else { return None }
  if arbitrary {
    if argument.has_prefix("[") && argument.has_suffix("]") {
      let data_type = trim(argument[1:argument.length() - 1].to_owned())
      if data_type == "*" {
        return Some(value)
      }
      match value_data_type {
        Some(hint) => return if hint == data_type { Some(value) } else { None }
        None => ()
      }
      if (data_type == "integer" && is_nonnegative_integer(value)) ||
        (data_type == "number" && is_spacing_number(value)) ||
        (
          data_type == "percentage" &&
          value.has_suffix("%") &&
          is_nonnegative_integer(value[:value.length() - 1].to_owned())
        ) ||
        (data_type == "ratio" && normalize_ratio(value, false) is Some(_)) {
        return Some(value)
      }
    }
    return None
  }
  if argument.length() >= 2 &&
    (
      (argument.has_prefix("'") && argument.has_suffix("'")) ||
      (argument.has_prefix("\"") && argument.has_suffix("\""))
    ) {
    let literal = argument[1:argument.length() - 1].to_owned()
    return if literal == value { Some(value) } else { None }
  }
  if argument == "integer" {
    return if is_nonnegative_integer(value) { Some(value) } else { None }
  }
  if argument == "number" {
    return if is_spacing_number(value) { Some(value) } else { None }
  }
  if argument == "percentage" &&
    value.has_suffix("%") &&
    is_nonnegative_integer(value[:value.length() - 1].to_owned()) {
    return Some(value)
  }
  if argument == "ratio" {
    return normalize_ratio(value, true)
  }
  if argument.has_prefix("--") {
    let key = if argument.contains("-*") {
      replace_all(argument, "*", value)
    } else {
      "\{argument}-\{value}"
    }
    match theme.get(key) {
      Some(_) => return theme_css_value(theme, key)
      None => return None
    }
  }
  None
}

///|
fn substitute_functional_values(
  input : String,
  function_name : String,
  value : String?,
  arbitrary : Bool,
  value_data_type : String?,
  theme : Map[String, String],
) -> (String?, Bool) {
  let (nodes, used) = substitute_functional_value_ast(
    parse_value(input),
    function_name,
    value,
    arbitrary,
    value_data_type,
    theme,
  )
  (nodes.map(fn(nodes) { render_value(nodes) }), used)
}

///|
fn substitute_functional_value_ast(
  nodes : ArrayView[ValueNode],
  function_name : String,
  value : String?,
  arbitrary : Bool,
  value_data_type : String?,
  theme : Map[String, String],
) -> (Array[ValueNode]?, Bool) {
  let output : Array[ValueNode] = []
  let mut used = false
  for node in nodes {
    match node {
      ValueFunction(name, children) =>
        if name == function_name {
          used = true
          let arguments = split_function_arguments(render_value(children))
          let mut resolved : String? = None
          for argument in arguments {
            match
              resolve_functional_argument(
                argument, value, arbitrary, value_data_type, theme,
              ) {
              Some(result) => {
                resolved = Some(result)
                break
              }
              None => ()
            }
          }
          guard resolved is Some(result) else { return (None, true) }
          for replacement in parse_value(result) {
            output.push(replacement)
          }
        } else {
          let (children, child_used) = substitute_functional_value_ast(
            children, function_name, value, arbitrary, value_data_type, theme,
          )
          guard children is Some(children) else {
            return (None, used || child_used)
          }
          used = used || child_used
          output.push(ValueFunction(name, children))
        }
      _ => output.push(node)
    }
  }
  (Some(output), used)
}

///|
priv struct FunctionalContext {
  theme : Map[String, String]
  value : String?
  arbitrary : Bool
  value_data_type : String?
  modifier : String?
  modifier_value : String?
  modifier_arbitrary : Bool
  modifier_data_type : String?
  mut resolved_value : Bool
  mut used_modifier : Bool
  mut resolved_modifier : Bool
  mut resolved_ratio : Bool
  ratios : Array[Bool]
}

///|
/// Substitute `--value()` and `--modifier()` throughout a functional `@utility`
/// body, dropping declarations whose arguments do not resolve.
fn substitute_functional_body(
  nodes : ArrayView[CssNode],
  context : FunctionalContext,
) -> Array[CssNode] {
  let output : Array[CssNode] = []
  for node in nodes {
    match node {
      Declaration(name~, value=raw, important~, span~) => {
        let declaration_ratio = raw.contains("--value(ratio")
        let value_for_declaration = if declaration_ratio {
          match (context.value, context.modifier_value) {
            (Some(left), Some(right)) => Some("\{left}/\{right}")
            _ => context.value
          }
        } else {
          context.value
        }
        let (with_value, used_value) = substitute_functional_values(
          raw,
          "--value",
          value_for_declaration,
          context.arbitrary,
          context.value_data_type,
          context.theme,
        )
        guard with_value is Some(with_value) else { continue }
        if used_value {
          context.resolved_value = true
          if declaration_ratio {
            context.resolved_ratio = true
          }
        }
        let (with_modifier, declaration_used_modifier) = substitute_functional_values(
          with_value,
          "--modifier",
          context.modifier_value,
          context.modifier_arbitrary,
          context.modifier_data_type,
          context.theme,
        )
        context.used_modifier = context.used_modifier ||
          declaration_used_modifier
        match with_modifier {
          Some(resolved) => {
            if declaration_used_modifier {
              context.resolved_modifier = true
            }
            context.ratios.push(declaration_ratio)
            output.push(Declaration(name~, value=resolved, important~, span~))
          }
          None => ()
        }
      }
      Rule(selector~, nodes=children, span~) =>
        output.push(
          Rule(
            selector~,
            nodes=substitute_functional_body(children, context),
            span~,
          ),
        )
      AtRule(name~, params~, nodes=Some(children), span~) =>
        output.push(
          AtRule(
            name~,
            params~,
            nodes=Some(substitute_functional_body(children, context)),
            span~,
          ),
        )
      _ => output.push(node)
    }
  }
  output
}

///|
/// Keep only the ratio form of a declaration set once a ratio value resolved.
fn keep_ratio_declarations(
  nodes : ArrayView[CssNode],
  ratios : ArrayView[Bool],
  cursor : Ref[Int],
) -> Array[CssNode] {
  let output : Array[CssNode] = []
  for node in nodes {
    match node {
      Declaration(..) => {
        let index = cursor.val
        cursor.val = index + 1
        if index < ratios.length() && ratios[index] {
          output.push(node)
        }
      }
      Rule(selector~, nodes=children, span~) =>
        output.push(
          Rule(
            selector~,
            nodes=keep_ratio_declarations(children, ratios, cursor),
            span~,
          ),
        )
      AtRule(name~, params~, nodes=Some(children), span~) =>
        output.push(
          AtRule(
            name~,
            params~,
            nodes=Some(keep_ratio_declarations(children, ratios, cursor)),
            span~,
          ),
        )
      _ => output.push(node)
    }
  }
  output
}

///|
fn compile_functional_utility(
  theme : Map[String, String],
  name : String,
  modifier : String?,
  functional : Map[String, Array[CssNode]],
) -> Array[CssNode]? {
  for root, body in functional {
    guard functional_candidate_value(root, name)
      is Some((value, arbitrary, value_data_type)) else {
      continue
    }
    let (modifier_value, modifier_arbitrary, modifier_data_type) = match
      modifier {
      Some(raw) => {
        let (value, arbitrary, data_type) = unpack_functional_value(raw)
        (Some(value), arbitrary, data_type)
      }
      None => (None, false, None)
    }
    let context : FunctionalContext = {
      theme,
      value,
      arbitrary,
      value_data_type,
      modifier,
      modifier_value,
      modifier_arbitrary,
      modifier_data_type,
      resolved_value: false,
      used_modifier: false,
      resolved_modifier: false,
      resolved_ratio: false,
      ratios: [],
    }
    let substituted = substitute_functional_body(body, context)
    if !context.resolved_value ||
      (
        context.modifier is Some(_) &&
        !context.resolved_ratio &&
        (!context.used_modifier || !context.resolved_modifier)
      ) {
      return None
    }
    let result = if context.resolved_ratio {
      keep_ratio_declarations(substituted, context.ratios, { val: 0 })
    } else {
      substituted
    }
    return if count_declarations(result) == 0 { None } else { Some(result) }
  }
  None
}

///|
fn count_declarations(nodes : ArrayView[CssNode]) -> Int {
  let mut total = 0
  for node in nodes {
    match node {
      Declaration(..) => total += 1
      Rule(nodes=children, ..)
      | AtRule(nodes=Some(children), ..)
      | Context(nodes=children, ..) => total += count_declarations(children)
      _ => ()
    }
  }
  total
}
