///|
fn trim(s : String) -> String {
  s.trim().to_owned()
}

///|
fn replace_all(s : String, old : String, replacement : String) -> String {
  if old == "" {
    return s
  }
  s.split(old).map(fn(part) { part.to_owned() }).collect().join(replacement)
}

///|
/// Split `input` on every `separator` that is not nested inside brackets or a
/// string, mirroring the upstream `segment` helper.
fn split_top_level(input : String, separator : Char) -> Array[String] {
  let parts : Array[String] = []
  let stack : Array[Char] = []
  let mut current = StringBuilder()
  let mut escaped = false
  let mut quote : Char? = None
  for character in input {
    if escaped {
      current.write_char(character)
      escaped = false
      continue
    }
    if quote is Some(open) {
      current.write_char(character)
      if character == '\\' {
        escaped = true
      } else if character == open {
        quote = None
      }
      continue
    }
    if stack.is_empty() && character == separator {
      parts.push(current.to_string())
      current = StringBuilder()
      continue
    }
    match character {
      '\\' => escaped = true
      '"' | '\'' => quote = Some(character)
      '(' => stack.push(')')
      '[' => stack.push(']')
      '{' => stack.push('}')
      ')' | ']' | '}' =>
        if stack.last() is Some(expected) && expected == character {
          stack.pop() |> ignore
        }
      _ => ()
    }
    current.write_char(character)
  }
  parts.push(current.to_string())
  parts
}

///|
/// Return the index of the first occurrence of `needle` in `haystack`.
fn index_of(haystack : String, needle : String) -> Int? {
  if needle == "" {
    return Some(0)
  }
  let limit = haystack.length() - needle.length()
  if limit < 0 {
    return None
  }
  for start in 0..<=limit {
    if haystack[start:start + needle.length()] == needle {
      return Some(start)
    }
  }
  None
}

///|
fn escape_class_name(s : String) -> String {
  let out = StringBuilder()
  for c in s {
    match c {
      'a'..='z' | 'A'..='Z' | '0'..='9' | '-' | '_' => out.write_char(c)
      _ => {
        out.write_char('\\')
        out.write_char(c)
      }
    }
  }
  out.to_string()
}

///|
fn decode_underscores(input : String, preserve~ : Bool) -> String {
  let output = StringBuilder()
  let mut index = 0
  while index < input.length() {
    if input[index] == '\\' &&
      index + 1 < input.length() &&
      input[index + 1] == '_' {
      output.write_char('_')
      index += 2
    } else if input[index] == '_' && !preserve {
      output.write_char(' ')
      index += 1
    } else {
      output.write_view(input[index:index + 1])
      index += 1
    }
  }
  output.to_string()
}

///|
fn decode_arbitrary_node(node : ValueNode) -> ValueNode {
  match node {
    ValueWord(value) => ValueWord(decode_underscores(value, preserve=false))
    ValueSeparator(value) =>
      ValueSeparator(decode_underscores(value, preserve=false))
    ValueFunction(name, children) => {
      let decoded_name = decode_underscores(name, preserve=false)
      if name == "url" || name.has_suffix("_url") {
        ValueFunction(decoded_name, children)
      } else if name == "var" ||
        name.has_suffix("_var") ||
        name == "theme" ||
        name.has_suffix("_theme") {
        let decoded_children : Array[ValueNode] = []
        for index, child in children {
          decoded_children.push(
            match child {
              ValueWord(value) if index == 0 =>
                ValueWord(decode_underscores(value, preserve=true))
              _ => decode_arbitrary_node(child)
            },
          )
        }
        ValueFunction(decoded_name, decoded_children)
      } else {
        ValueFunction(decoded_name, children.map(decode_arbitrary_node))
      }
    }
  }
}

///|
fn is_math_function(name : String) -> Bool {
  [
    "calc", "min", "max", "clamp", "mod", "rem", "sin", "cos", "tan", "asin", "acos",
    "atan", "atan2", "pow", "sqrt", "hypot", "log", "exp", "round",
  ].contains(name)
}

///|
fn add_math_whitespace(input : String) -> String {
  let output = StringBuilder()
  let math_stack : Array[Bool] = []
  let mut index = 0
  let mut previous_output : UInt16? = None
  let mut previous_significant : UInt16? = None
  while index < input.length() {
    let current = input[index]
    if current == '(' {
      let mut start = index
      while start > 0 {
        let previous = input[start - 1]
        if (previous >= 'a' && previous <= 'z') ||
          (previous >= '0' && previous <= '9') {
          start -= 1
        } else {
          break
        }
      }
      let name = input[start:index].to_owned()
      let parent_math = math_stack.last().unwrap_or(false)
      math_stack.push(is_math_function(name) || (parent_math && name == ""))
      output.write_char('(')
      previous_output = Some('(')
      previous_significant = Some('(')
      index += 1
      continue
    }
    if current == ')' {
      ignore(math_stack.pop())
      output.write_char(')')
      previous_output = Some(')')
      previous_significant = Some(')')
      index += 1
      continue
    }
    let in_math = math_stack.last().unwrap_or(false)
    if in_math && current == ',' {
      output.write_string(", ")
      previous_output = Some(' ')
      previous_significant = Some(',')
      index += 1
      while index < input.length() && input[index] == ' ' {
        index += 1
      }
      continue
    }
    if in_math && current == ' ' && previous_output == Some(' ') {
      index += 1
      continue
    }
    if in_math &&
      (current == '+' || current == '-' || current == '*' || current == '/') {
      let previous_input = if index > 0 { Some(input[index - 1]) } else { None }
      let next = if index + 1 < input.length() {
        Some(input[index + 1])
      } else {
        None
      }
      let exponent = (
          previous_input == Some('e') || previous_input == Some('E')
        ) &&
        index > 1 &&
        input[index - 2] >= '0' &&
        input[index - 2] <= '9'
      let unary = previous_significant is None ||
        previous_significant == Some('(') ||
        previous_significant == Some(',') ||
        previous_significant == Some('+') ||
        previous_significant == Some('-') ||
        previous_significant == Some('*') ||
        previous_significant == Some('/')
      let custom_property_dash = current == '-' &&
        (previous_input == Some('-') || next == Some('-'))
      if !exponent && !unary && !custom_property_dash {
        if previous_output != Some(' ') {
          output.write_char(' ')
        }
        output.write_view(input[index:index + 1])
        if next != Some(' ') {
          output.write_char(' ')
          previous_output = Some(' ')
        } else {
          previous_output = Some(current)
        }
        previous_significant = Some(current)
        index += 1
        continue
      }
    }
    output.write_view(input[index:index + 1])
    previous_output = Some(current)
    if current != ' ' {
      previous_significant = Some(current)
    }
    index += 1
  }
  output.to_string()
}

///|
fn decode_arbitrary(s : String) -> String {
  if !s.contains("(") {
    return decode_underscores(s, preserve=false)
  }
  let decoded = parse_value(s).map(decode_arbitrary_node)
  add_math_whitespace(render_value(decoded))
}

///|
fn is_valid_arbitrary(input : String) -> Bool {
  let closing : Array[UInt16] = []
  let mut index = 0
  while index < input.length() {
    let current = input[index]
    if current == '\\' {
      index += 2
      continue
    }
    if current == '\'' || current == '"' {
      let quote = current
      index += 1
      while index < input.length() && input[index] != quote {
        if input[index] == '\\' {
          index += 2
        } else {
          index += 1
        }
      }
      index += 1
      continue
    }
    match current {
      '(' => closing.push(')')
      '[' => closing.push(']')
      '{' => ()
      ')' | ']' | '}' => {
        let valid = match closing.pop() {
          Some(expected) => current == expected
          None => false
        }
        if !valid {
          return false
        }
      }
      ';' => if closing.is_empty() { return false }
      _ => ()
    }
    index += 1
  }
  closing.is_empty()
}

///|
fn lexical_compare(a : String, b : String) -> Int {
  let common = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<common {
    if a[i] < b[i] {
      return -1
    }
    if a[i] > b[i] {
      return 1
    }
  }
  a.length().compare(b.length())
}

///|
fn candidate_lexical_compare(a : String, b : String) -> Int {
  let a_gradient_arbitrary = a.has_prefix("bg-linear-[")
  let b_gradient_arbitrary = b.has_prefix("bg-linear-[")
  if a_gradient_arbitrary != b_gradient_arbitrary {
    return if a_gradient_arbitrary { 1 } else { -1 }
  }
  let a_typography = a.has_prefix("font-") || a.has_prefix("text-")
  let b_typography = b.has_prefix("font-") || b.has_prefix("text-")
  let a_typography_rank = if a_typography && a.contains("/") {
    2
  } else if a_typography && (a.has_prefix("font-[") || a.has_prefix("text-[")) {
    1
  } else {
    0
  }
  let b_typography_rank = if b_typography && b.contains("/") {
    2
  } else if b_typography && (b.has_prefix("font-[") || b.has_prefix("text-[")) {
    1
  } else {
    0
  }
  if a_typography_rank != b_typography_rank {
    a_typography_rank.compare(b_typography_rank)
  } else {
    lexical_compare(a, b)
  }
}

///|
fn split_variants(candidate : String) -> Array[String] {
  let parts : Array[String] = []
  let buf = StringBuilder()
  let mut depth = 0
  for c in candidate {
    match c {
      '[' | '(' => {
        depth += 1
        buf.write_char(c)
      }
      ']' | ')' => {
        depth -= 1
        buf.write_char(c)
      }
      ':' =>
        if depth == 0 {
          parts.push(buf.to_string())
          buf.reset()
        } else {
          buf.write_char(c)
        }
      _ => buf.write_char(c)
    }
  }
  parts.push(buf.to_string())
  parts
}
