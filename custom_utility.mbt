///|
/// Names accepted by `@utility`, matching the upstream grammar.
fn is_valid_utility_name(name : String) -> Bool {
  if name == "" {
    return false
  }
  let first = name[0]
  if !((first >= 'a' && first <= 'z') || (first >= '0' && first <= '9')) {
    return false
  }
  for character in name {
    if !((character >= 'a' && character <= 'z') ||
      (character >= 'A' && character <= 'Z') ||
      (character >= '0' && character <= '9') ||
      character == '-' ||
      character == '_' ||
      character == '.' ||
      character == '%' ||
      character == '/') {
      return false
    }
  }
  !name.has_suffix("-") && !name.has_suffix("_")
}

///|
fn parse_custom_utilities(
  nodes : ArrayView[CssNode],
) -> (Map[String, Array[CssNode]], Map[String, Array[CssNode]]) raise CompileError {
  let utilities : Map[String, Array[CssNode]] = Map([])
  let functional : Map[String, Array[CssNode]] = Map([])
  collect_custom_utilities(nodes, utilities, functional)
  (utilities, functional)
}

///|
/// Collect `@utility` definitions in document order into the accumulators.
///
/// `Context` and `AtRoot` are transparent structural wrappers: `resolve_imports`
/// splices each imported stylesheet in behind a `Context`, so a top-level
/// `@utility` in an imported file is semantically top-level and must be
/// collected through the wrapper. `@utility` genuinely nested inside a `Rule` or
/// a real at-rule remains illegal.
fn collect_custom_utilities(
  nodes : ArrayView[CssNode],
  utilities : Map[String, Array[CssNode]],
  functional : Map[String, Array[CssNode]],
) -> Unit raise CompileError {
  for node in nodes {
    match node {
      AtRule(name="@utility", params~, nodes=Some(children), ..) => {
        let utility_name = trim(params)
        if utility_name == "" {
          raise InvalidCss("Invalid @utility name")
        }
        let is_functional = utility_name.has_suffix("-*")
        if utility_name.contains("*") && !is_functional {
          raise InvalidCss(
            "A functional @utility must contain `-*` once at the end",
          )
        }
        let root = if is_functional {
          utility_name[:utility_name.length() - 2].to_owned()
        } else {
          utility_name
        }
        if !is_valid_utility_name(root) {
          raise InvalidCss("Invalid @utility name: \{utility_name}")
        }
        if children.is_empty() {
          raise InvalidCss("@utility \{utility_name} is empty")
        }
        for child in children {
          match child {
            AtRule(name="@utility", ..) =>
              raise InvalidCss("@utility cannot be nested")
            _ => ()
          }
        }
        if is_functional {
          functional[root] = children.copy()
        } else {
          utilities[root] = children.copy()
        }
      }
      Context(nodes~, ..) | AtRoot(nodes~, ..) =>
        collect_custom_utilities(nodes, utilities, functional)
      Rule(nodes~, ..) | AtRule(nodes=Some(nodes), ..) =>
        for child in nodes {
          match child {
            AtRule(name="@utility", ..) =>
              raise InvalidCss("@utility cannot be nested")
            _ => ()
          }
        }
      _ => ()
    }
  }
}

///|
fn remove_custom_utility_nodes(
  nodes : ArrayView[CssNode],
) -> (Array[CssNode], Bool) {
  let output : Array[CssNode] = []
  let mut changed = false
  for node in nodes {
    match node {
      AtRule(name="@utility", ..) => changed = true
      Rule(selector~, nodes~, span~) => {
        let (children, child_changed) = remove_custom_utility_nodes(nodes)
        changed = changed || child_changed
        output.push(Rule(selector~, nodes=children, span~))
      }
      AtRule(name~, params~, nodes=Some(nodes), span~) => {
        let (children, child_changed) = remove_custom_utility_nodes(nodes)
        changed = changed || child_changed
        output.push(AtRule(name~, params~, nodes=Some(children), span~))
      }
      Context(values~, nodes=children, span~) => {
        let (inner, inner_changed) = remove_custom_utility_nodes(children)
        changed = changed || inner_changed
        output.push(Context(values~, nodes=inner, span~))
      }
      _ => output.push(node)
    }
  }
  (output, changed)
}

///|
/// Expand `@apply` inside `@utility` bodies.
///
/// A utility may apply another custom utility, so bodies are resolved
/// recursively and a repeated visit is reported as a circular dependency.
fn apply_candidate_roots(nodes : ArrayView[CssNode]) -> Array[String] {
  let roots : Array[String] = []
  for node in nodes {
    match node {
      AtRule(name="@apply", params~, nodes=None, ..) =>
        for candidate in params.split(" ") {
          let raw = trim(candidate.to_owned())
          if raw == "" {
            continue
          }
          match parse_candidate(raw) {
            Some(parsed) => roots.push(parsed.base())
            None => roots.push(raw)
          }
        }
      Rule(nodes=children, ..)
      | AtRule(nodes=Some(children), ..)
      | Context(nodes=children, ..) =>
        for root in apply_candidate_roots(children) {
          roots.push(root)
        }
      _ => ()
    }
  }
  roots
}

///|
fn resolve_custom_utility_bodies(
  utilities : Map[String, Array[CssNode]],
  functional : Map[String, Array[CssNode]],
  theme : Map[String, String],
  custom_variants : Map[String, CustomVariantTemplate],
) -> (Map[String, Array[CssNode]], Map[String, Array[CssNode]]) raise CompileError {
  let resolved : Map[String, Array[CssNode]] = Map([])
  fn resolve(name : String, chain : Array[String]) -> Unit raise CompileError {
    if resolved.contains(name) {
      return
    }
    if chain.contains(name) {
      raise InvalidCss(
        "You cannot `@apply` the `\{name}` utility here because it creates a circular dependency.",
      )
    }
    guard utilities.get(name) is Some(body) else { return }
    let next_chain = chain.copy()
    next_chain.push(name)
    for dependency in apply_candidate_roots(body) {
      if utilities.contains(dependency) {
        resolve(dependency, next_chain)
      }
    }
    let (substituted, _) = substitute_apply(
      body, theme, resolved, functional, custom_variants,
    )
    resolved[name] = substituted
  }

  for name, _ in utilities {
    resolve(name, [])
  }
  let resolved_functional : Map[String, Array[CssNode]] = Map([])
  for name, body in functional {
    let (substituted, _) = substitute_apply(
      body, theme, resolved, functional, custom_variants,
    )
    resolved_functional[name] = substituted
  }
  (resolved, resolved_functional)
}
