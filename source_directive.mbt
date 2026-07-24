///|
priv struct SourceDirectives {
  sources : Array[Source]
  included : Array[String]
  excluded : Map[String, Unit]
}

///|
fn quoted_content(input : String) -> String? {
  let value = trim(input)
  if value.length() < 2 {
    return None
  }
  if (value.has_prefix("\"") && value.has_suffix("\"")) ||
    (value.has_prefix("'") && value.has_suffix("'")) {
    Some(value[1:value.length() - 1].to_owned())
  } else {
    None
  }
}

///|
fn inline_source_content(params : String) -> String? raise CompileError {
  let value = trim(params)
  let marker = "inline("
  guard value.to_lower().find(marker) is Some(start) else { return None }
  let open = start + marker.length() - 1
  let close = find_function_end(value, open)
  quoted_content(value[open + 1:close].to_owned())
}

///|
fn parse_source_directives(
  nodes : ArrayView[CssNode],
  base : String,
) -> SourceDirectives raise CompileError {
  let result = { sources: [], included: [], excluded: Map([]) }
  for node in nodes {
    match node {
      AtRule(name="@source", params~, ..) => {
        let value = trim(params)
        let negated = value.has_prefix("not ")
        let target = if negated { trim(value[4:].to_owned()) } else { value }
        match inline_source_content(target) {
          Some(content) =>
            for raw in content.split(" ") {
              let candidate = trim(raw.to_owned())
              if candidate != "" {
                if negated {
                  result.excluded[candidate] = ()
                } else {
                  result.included.push(candidate)
                }
              }
            }
          None =>
            match quoted_content(target) {
              Some(pattern) => result.sources.push({ base, pattern, negated })
              None => raise InvalidCss("Invalid @source directive: \{params}")
            }
        }
      }
      // An imported file carries its own base for `@source` resolution.
      Context(values~, nodes~, ..) => {
        let nested = parse_source_directives(
          nodes,
          values.get("base").unwrap_or(base),
        )
        for source in nested.sources {
          result.sources.push(source)
        }
        for candidate in nested.included {
          result.included.push(candidate)
        }
        for candidate, _ in nested.excluded {
          result.excluded[candidate] = ()
        }
      }
      Rule(nodes~, ..) | AtRule(nodes=Some(nodes), ..) => {
        let nested = parse_source_directives(nodes, base)
        for source in nested.sources {
          result.sources.push(source)
        }
        for candidate in nested.included {
          result.included.push(candidate)
        }
        for candidate, _ in nested.excluded {
          result.excluded[candidate] = ()
        }
      }
      _ => ()
    }
  }
  result
}

///|
fn remove_source_nodes(nodes : ArrayView[CssNode]) -> (Array[CssNode], Bool) {
  let output : Array[CssNode] = []
  let mut changed = false
  for node in nodes {
    match node {
      AtRule(name="@source", ..) => changed = true
      Rule(selector~, nodes~, span~) => {
        let (children, child_changed) = remove_source_nodes(nodes)
        changed = changed || child_changed
        output.push(Rule(selector~, nodes=children, span~))
      }
      AtRule(name~, params~, nodes=Some(nodes), span~) => {
        let (children, child_changed) = remove_source_nodes(nodes)
        changed = changed || child_changed
        output.push(AtRule(name~, params~, nodes=Some(children), span~))
      }
      Context(values~, nodes=children, span~) => {
        let (inner, inner_changed) = remove_source_nodes(children)
        changed = changed || inner_changed
        output.push(Context(values~, nodes=inner, span~))
      }
      _ => output.push(node)
    }
  }
  (output, changed)
}
