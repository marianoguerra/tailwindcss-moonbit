///|
priv enum ValueNode {
  ValueWord(String)
  ValueFunction(String, Array[ValueNode])
  ValueSeparator(String)
} derive(Eq, Debug)

///|
fn is_value_separator(c : UInt16) -> Bool {
  c == ':' ||
  c == ',' ||
  c == '=' ||
  c == '>' ||
  c == '<' ||
  c == '\n' ||
  c == ' ' ||
  c == '\t'
}

///|
fn parse_value_nodes(
  input : String,
  start : Int,
  nested : Bool,
) -> (Array[ValueNode], Int) {
  let nodes : Array[ValueNode] = []
  let mut buffer = ""
  let mut index = start
  while index < input.length() {
    let current = input[index]
    if current == '\\' {
      buffer += input[index:index + 1].to_owned()
      if index + 1 < input.length() {
        buffer += input[index + 1:index + 2].to_owned()
        index += 2
      } else {
        index += 1
      }
      continue
    }
    if current == '\'' || current == '"' {
      let quote = current
      buffer += input[index:index + 1].to_owned()
      index += 1
      while index < input.length() {
        let c = input[index]
        buffer += input[index:index + 1].to_owned()
        index += 1
        if c == '\\' && index < input.length() {
          buffer += input[index:index + 1].to_owned()
          index += 1
        } else if c == quote {
          break
        }
      }
      continue
    }
    if current == '(' {
      let function_name = buffer
      buffer = ""
      let (children, next) = parse_value_nodes(input, index + 1, true)
      nodes.push(ValueFunction(function_name, children))
      index = next
      continue
    }
    if current == ')' {
      if buffer != "" {
        nodes.push(ValueWord(buffer))
        buffer = ""
      }
      if nested {
        return (nodes, index + 1)
      }
      index += 1
      continue
    }
    if current == '/' {
      if buffer != "" {
        nodes.push(ValueWord(buffer))
        buffer = ""
      }
      nodes.push(ValueWord("/"))
      index += 1
      continue
    }
    if is_value_separator(current) {
      if buffer != "" {
        nodes.push(ValueWord(buffer))
        buffer = ""
      }
      let separator = StringBuilder()
      while index < input.length() && is_value_separator(input[index]) {
        separator.write_view(input[index:index + 1])
        index += 1
      }
      nodes.push(ValueSeparator(separator.to_string()))
      continue
    }
    buffer += input[index:index + 1].to_owned()
    index += 1
  }
  if buffer != "" {
    nodes.push(ValueWord(buffer))
  }
  (nodes, index)
}

///|
fn parse_value(input : String) -> Array[ValueNode] {
  parse_value_nodes(replace_all(input, "\r\n", "\n"), 0, false).0
}

///|
fn render_value(nodes : ArrayView[ValueNode]) -> String {
  let output = StringBuilder()
  for node in nodes {
    match node {
      ValueWord(value) | ValueSeparator(value) => output.write_string(value)
      ValueFunction(name, children) => {
        output.write_string(name)
        output.write_char('(')
        output.write_string(render_value(children))
        output.write_char(')')
      }
    }
  }
  output.to_string()
}
