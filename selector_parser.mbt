///|
priv enum SelectorNode {
  Selector(String)
  SelectorValue(String)
  SelectorCombinator(String)
  SelectorFunction(String, Array[SelectorNode])
  SelectorComplex(Array[SelectorNode])
  SelectorCompound(Array[SelectorNode])
  SelectorList(Array[SelectorNode])
} derive(Eq, Debug)

///|
fn selector_function_is_structured(name : String) -> Bool {
  name == ":is" || name == ":where" || name == ":not" || name == ":has"
}

///|
fn selector_matching_end(
  input : String,
  start : Int,
  opening : UInt16,
  closing : UInt16,
) -> Int {
  let mut depth = 1
  let mut quote : UInt16? = None
  let mut index = start + 1
  while index < input.length() {
    let current = input[index]
    match quote {
      Some(expected) => {
        if current == '\\' {
          index += 2
          continue
        }
        if current == expected {
          quote = None
        }
      }
      None =>
        if current == '\'' || current == '"' {
          quote = Some(current)
        } else if current == '\\' {
          index += 2
          continue
        } else if current == opening {
          depth += 1
        } else if current == closing {
          depth -= 1
          if depth == 0 {
            return index
          }
        }
    }
    index += 1
  }
  input.length() - 1
}

///|
fn selector_is_space(character : UInt16) -> Bool {
  character == ' ' || character == '\n' || character == '\t'
}

///|
fn selector_is_explicit_combinator(character : UInt16) -> Bool {
  character == '>' || character == '+' || character == '~'
}

///|
fn selector_is_token_start(character : UInt16) -> Bool {
  character == '.' ||
  character == '#' ||
  character == ':' ||
  character == '[' ||
  character == '&' ||
  character == '*'
}

///|
fn selector_find_top_level_of(input : String) -> Int {
  let mut index = 0
  while index + 2 < input.length() {
    if input[index] == '\\' {
      index += 2
      continue
    }
    if input[index] == '\'' || input[index] == '"' {
      index = selector_matching_end(input, index, input[index], input[index]) +
        1
      continue
    }
    if input[index] == '(' {
      index = selector_matching_end(input, index, '(', ')') + 1
      continue
    }
    if input[index] == '[' {
      index = selector_matching_end(input, index, '[', ']') + 1
      continue
    }
    if input[index:index + 3] == "of " {
      return index
    }
    index += 1
  }
  -1
}

///|
fn parse_selector_compound(input : String) -> SelectorNode {
  let nodes : Array[SelectorNode] = []
  let mut index = 0
  while index < input.length() {
    let start = index
    let current = input[index]
    if current == '[' {
      let close = selector_matching_end(input, index, '[', ']')
      nodes.push(Selector(input[index:close + 1].to_owned()))
      index = close + 1
      continue
    }
    if current == '&' || current == '*' {
      nodes.push(Selector(input[index:index + 1].to_owned()))
      index += 1
      continue
    }
    if current == '.' || current == '#' || current == ':' {
      index += 1
      if current == ':' && index < input.length() && input[index] == ':' {
        index += 1
      }
      while index < input.length() && !selector_is_token_start(input[index]) {
        if input[index] == '\\' {
          index = if index + 2 > input.length() {
            input.length()
          } else {
            index + 2
          }
        } else if input[index] == '(' {
          break
        } else {
          index += 1
        }
      }
      if index < input.length() && input[index] == '(' {
        let name = input[start:index].to_owned()
        let close = selector_matching_end(input, index, '(', ')')
        // An unmatched `(` runs to the end of the input.
        let matched = close < input.length() &&
          close >= index + 1 &&
          input[close] == ')'
        let contents = if matched {
          input[index + 1:close].to_owned()
        } else {
          input[index + 1:].to_owned()
        }
        let children = if selector_function_is_structured(name) {
          parse_selector(contents)
        } else if name == ":nth-child" || name == ":nth-last-child" {
          let of_index = selector_find_top_level_of(contents)
          if of_index < 0 {
            [SelectorValue(contents)]
          } else {
            let result : Array[SelectorNode] = [
              SelectorValue(contents[:of_index + 3].to_owned()),
            ]
            result.append(parse_selector(contents[of_index + 3:].to_owned()))
            result
          }
        } else {
          [SelectorValue(contents)]
        }
        nodes.push(SelectorFunction(name, children))
        index = if matched { close + 1 } else { input.length() }
      } else {
        nodes.push(Selector(input[start:index].to_owned()))
      }
      continue
    }
    while index < input.length() && !selector_is_token_start(input[index]) {
      if input[index] == '\\' {
        index = if index + 2 > input.length() {
          input.length()
        } else {
          index + 2
        }
      } else {
        index += 1
      }
    }
    if index > start {
      nodes.push(Selector(input[start:index].to_owned()))
    }
  }
  match nodes {
    [node] => node
    _ => SelectorCompound(nodes)
  }
}

///|
fn parse_selector_complex(input : String) -> SelectorNode {
  let nodes : Array[SelectorNode] = []
  let mut segment_start = 0
  let mut index = 0
  while index < input.length() {
    let current = input[index]
    if current == '\\' {
      index += 2
      continue
    }
    if current == '[' {
      index = selector_matching_end(input, index, '[', ']') + 1
      continue
    }
    if current == '(' {
      index = selector_matching_end(input, index, '(', ')') + 1
      continue
    }
    if selector_is_space(current) || selector_is_explicit_combinator(current) {
      let segment = trim(input[segment_start:index].to_owned())
      if segment != "" {
        nodes.push(parse_selector_compound(segment))
      }
      let mut end = index + 1
      while end < input.length() &&
            (
              selector_is_space(input[end]) ||
              selector_is_explicit_combinator(input[end])
            ) {
        end += 1
      }
      let run = trim(input[index:end].to_owned())
      if (run != "" || !nodes.is_empty()) && end < input.length() {
        nodes.push(SelectorCombinator(if run == "" { " " } else { run }))
      }
      segment_start = end
      index = end
      continue
    }
    index += 1
  }
  let tail = trim(input[segment_start:].to_owned())
  if tail != "" {
    nodes.push(parse_selector_compound(tail))
  }
  match nodes {
    [node] => node
    _ =>
      if nodes.any(fn(node) { node is SelectorCombinator(_) }) {
        SelectorComplex(nodes)
      } else {
        SelectorCompound(nodes)
      }
  }
}

///|
fn parse_selector(input : String) -> Array[SelectorNode] {
  let input = replace_all(input, "\r\n", "\n")
  let items : Array[SelectorNode] = []
  let mut start = 0
  let mut index = 0
  let mut saw_comma = false
  while index < input.length() {
    if input[index] == '\\' {
      index += 2
      continue
    }
    if input[index] == '[' {
      index = selector_matching_end(input, index, '[', ']') + 1
      continue
    }
    if input[index] == '(' {
      index = selector_matching_end(input, index, '(', ')') + 1
      continue
    }
    if input[index] == ',' {
      items.push(parse_selector_complex(trim(input[start:index].to_owned())))
      saw_comma = true
      index += 1
      while index < input.length() && selector_is_space(input[index]) {
        index += 1
      }
      start = index
      continue
    }
    index += 1
  }
  if saw_comma {
    items.push(parse_selector_complex(trim(input[start:].to_owned())))
    [SelectorList(items)]
  } else if input == "" {
    []
  } else {
    [parse_selector_complex(trim(input))]
  }
}

///|
fn render_selector(
  nodes : ArrayView[SelectorNode],
  minify? : Bool = false,
) -> String {
  let output = StringBuilder()
  for node in nodes {
    match node {
      Selector(value) | SelectorValue(value) => output.write_string(value)
      SelectorCombinator(" ") => output.write_char(' ')
      SelectorCombinator(value) =>
        if minify {
          output.write_string(value)
        } else {
          output.write_string(" \{value} ")
        }
      SelectorFunction(name, children) => {
        output.write_string(name)
        output.write_char('(')
        output.write_string(render_selector(children, minify~))
        output.write_char(')')
      }
      SelectorComplex(children) | SelectorCompound(children) =>
        output.write_string(render_selector(children, minify~))
      SelectorList(children) => {
        let rendered = children.map(fn(child) {
          render_selector([child], minify~)
        })
        output.write_string(rendered.join(if minify { "," } else { ", " }))
      }
    }
  }
  output.to_string()
}

///|
fn selector_contains_nesting(nodes : ArrayView[SelectorNode]) -> Bool {
  nodes.any(fn(node) {
    match node {
      Selector("&") => true
      SelectorFunction(_, children)
      | SelectorComplex(children)
      | SelectorCompound(children)
      | SelectorList(children) => selector_contains_nesting(children)
      _ => false
    }
  })
}

///|
fn replace_selector_nesting(
  nodes : ArrayView[SelectorNode],
  selector : String,
) -> Array[SelectorNode] {
  nodes.map(fn(node) {
    match node {
      Selector("&") => Selector(selector)
      SelectorFunction(name, children) =>
        SelectorFunction(name, replace_selector_nesting(children, selector))
      SelectorComplex(children) =>
        SelectorComplex(replace_selector_nesting(children, selector))
      SelectorCompound(children) =>
        SelectorCompound(replace_selector_nesting(children, selector))
      SelectorList(children) =>
        SelectorList(replace_selector_nesting(children, selector))
      _ => node
    }
  })
}

///|
fn rewrite_arbitrary_selector(arbitrary : String, selector : String) -> String {
  let ast = parse_selector(arbitrary)
  if selector_contains_nesting(ast) {
    render_selector(replace_selector_nesting(ast, selector))
  } else {
    "\{render_selector(ast)} \{selector}"
  }
}

///|
fn rewrite_selector_nesting_only(
  input : String,
  replacement : String,
) -> String {
  let ast = parse_selector(input)
  render_selector(replace_selector_nesting(ast, replacement))
}
