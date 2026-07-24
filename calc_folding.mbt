///|
/// Constant folding and unit canonicalization for CSS values.
///
/// This mirrors upstream `constant-fold-declaration.ts` and
/// `canonicalize-calc-expressions.ts`. Tailwind uses both to decide whether two
/// candidates mean the same thing, so like `expand-declaration` they never
/// touch the CSS that `compile` emits.

///|
/// Split a numeric token into its value and its unit.
fn split_numeric(input : String) -> (Double, String)? {
  if input == "" {
    return None
  }
  let mut end = input.length()
  while end > 0 {
    let character = input[end - 1]
    if (character >= 'a' && character <= 'z') ||
      (character >= 'A' && character <= 'Z') ||
      character == '%' {
      end -= 1
    } else {
      break
    }
  }
  let number = input[:end].to_owned()
  if number == "" || number == "-" || number == "+" {
    return None
  }
  let value = @string.parse_double(number) catch { _ => return None }
  Some((value, input[end:].to_owned()))
}

///|
/// Render a folded number without a trailing `.0`.
fn render_number(value : Double) -> String {
  if value == value.floor() && value.abs() < 1.0e15 {
    "\{value.to_int64()}"
  } else {
    "\{value}"
  }
}

///|
/// Convert a length, angle, time or frequency to its canonical unit.
///
/// `rem` gives the root font size in pixels; without it `rem` values stay as
/// they are, because they cannot be compared to pixels.
fn canonicalize_unit(input : String, rem? : Double) -> String? {
  guard split_numeric(input) is Some((value, unit)) else { return None }
  if unit == "" {
    return Some(render_number(value))
  }
  match unit.to_lower() {
    "in" => Some("\{render_number(value * 96.0)}px")
    "cm" => Some("\{render_number(value * 96.0 / 2.54)}px")
    "mm" => Some("\{render_number(value * 96.0 / 2.54 / 10.0)}px")
    "q" => Some("\{render_number(value * 96.0 / 2.54 / 10.0 / 4.0)}px")
    "pc" => Some("\{render_number(value * 96.0 / 6.0)}px")
    "pt" => Some("\{render_number(value * 96.0 / 72.0)}px")
    "rem" =>
      match rem {
        Some(size) => Some("\{render_number(value * size)}px")
        None => None
      }
    "grad" => Some("\{render_number(value * 0.9)}deg")
    "rad" => Some("\{render_number(value * 180.0 / @math.PI)}deg")
    "turn" => Some("\{render_number(value * 360.0)}deg")
    "ms" => Some("\{render_number(value / 1000.0)}s")
    "khz" => Some("\{render_number(value * 1000.0)}hz")
    _ => Some("\{render_number(value)}\{unit}")
  }
}

///|
/// Fold `left op right` when both operands are plain numbers.
fn fold_operation(left : String, operator : String, right : String) -> String? {
  guard split_numeric(left) is Some((left_value, left_unit)) else {
    return None
  }
  guard split_numeric(right) is Some((right_value, right_unit)) else {
    return None
  }
  match operator {
    "*" => {
      // Multiplying by zero collapses the whole product.
      if (left_value == 0.0 && left_unit == "") ||
        (right_value == 0.0 && right_unit == "") {
        return Some("0")
      }
      if left_value == 1.0 && left_unit == "" {
        return Some(right)
      }
      if right_value == 1.0 && right_unit == "" {
        return Some(left)
      }
      if left_unit == right_unit || left_unit == "" || right_unit == "" {
        let unit = if left_unit == "" { right_unit } else { left_unit }
        Some("\{render_number(left_value * right_value)}\{unit}")
      } else {
        None
      }
    }
    "+" =>
      if left_unit == right_unit {
        Some("\{render_number(left_value + right_value)}\{left_unit}")
      } else {
        None
      }
    "-" =>
      if left_unit == right_unit {
        Some("\{render_number(left_value - right_value)}\{left_unit}")
      } else {
        None
      }
    "/" => {
      if right_value == 0.0 || right_unit != "" {
        return None
      }
      let result = left_value / right_value
      // Upstream refuses to fold a division it cannot write exactly.
      if (result * 100.0).round() / 100.0 != result {
        return None
      }
      Some("\{render_number(result)}\{left_unit}")
    }
    _ => None
  }
}

///|
fn fold_calc_nodes(
  nodes : ArrayView[ValueNode],
  rem : Double?,
  convert_units : Bool,
) -> Array[ValueNode] {
  let output : Array[ValueNode] = []
  for node in nodes {
    match node {
      ValueWord(word) =>
        if convert_units && word != "0" {
          match canonicalize_unit(word, rem?) {
            Some(converted) => output.push(ValueWord(converted))
            None => output.push(node)
          }
        } else {
          output.push(node)
        }
      ValueFunction(name, children) => {
        let folded = fold_calc_nodes(children, rem, convert_units)
        if name == "calc" || name == "" {
          match fold_calc_children(folded) {
            Some(word) => output.push(word)
            None => output.push(ValueFunction(name, folded))
          }
        } else {
          output.push(ValueFunction(name, folded))
        }
      }
      _ => output.push(node)
    }
  }
  output
}

///|
/// Fold the `a op b` shape that a `calc()` body has once it is parsed.
fn fold_calc_children(nodes : ArrayView[ValueNode]) -> ValueNode? {
  guard nodes.length() == 5 else { return None }
  guard nodes[1] is ValueSeparator(_) && nodes[3] is ValueSeparator(_) else {
    return None
  }
  guard nodes[2] is ValueWord(operator) else { return None }
  let left = match nodes[0] {
    ValueWord(word) => word
    _ => return None
  }
  let right = match nodes[4] {
    ValueWord(word) => word
    _ => return None
  }
  fold_operation(left, operator, right).map(fn(word) { ValueWord(word) })
}

///|
/// Canonicalize and constant fold a CSS value.
#warnings("-unused_value")
fn canonicalize_calc_expressions(
  value : String,
  rem? : Double,
  convert_units? : Bool = true,
) -> String {
  render_value(fold_calc_nodes(parse_value(value), rem, convert_units))
}
