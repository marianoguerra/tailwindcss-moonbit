///|
priv struct ImportSpec {
  id : String
  layer : String?
  supports : String?
  media : String?
  reference : Bool
  theme_only : Bool
}

///|
fn consume_import_function(
  input : String,
  name : String,
) -> (String, String)? raise CompileError {
  let prefix = "\{name}("
  if !input.to_lower().has_prefix(prefix) {
    return None
  }
  let close = find_function_end(input, name.length())
  Some(
    (
      input[name.length() + 1:close].to_owned(),
      trim(input[close + 1:].to_owned()),
    ),
  )
}

///|
fn parse_import_spec(params : String) -> ImportSpec? raise CompileError {
  let value = trim(params)
  if value.has_prefix("url(") {
    return None
  }
  if value.length() < 2 {
    return None
  }
  let quote = value[0]
  if quote != '\'' && quote != '"' {
    return None
  }
  for i in 1..<value.length() {
    if value[i] == '\\' {
      continue
    }
    if value[i] == quote {
      let id = value[1:i].to_owned()
      let mut rest = trim(value[i + 1:].to_owned())
      let mut layer : String? = None
      let mut supports : String? = None
      let mut reference = false
      let mut theme_only = false
      // Modifiers (`layer()`, `supports()`, `theme()`, `source()`) may appear in
      // any order, so keep consuming from the front until none matches.
      let mut progressed = true
      while progressed {
        progressed = false
        match consume_import_function(rest, "layer") {
          Some((content, tail)) => {
            layer = Some(content)
            rest = tail
            progressed = true
          }
          None => ()
        }
        match consume_import_function(rest, "supports") {
          Some((content, tail)) => {
            supports = Some(content)
            rest = tail
            progressed = true
          }
          None => ()
        }
        match consume_import_function(rest, "theme") {
          Some((content, tail)) =>
            if trim(content).split(" ").contains("reference") {
              reference = true
              theme_only = true
              rest = tail
              progressed = true
            }
          None => ()
        }
        // `source(...)` controls automatic content detection for the imported
        // sheet. This surface takes candidates explicitly, so the directive is
        // consumed and discarded rather than emitted as a media condition.
        match consume_import_function(rest, "source") {
          Some((_, tail)) => {
            rest = tail
            progressed = true
          }
          None => ()
        }
      }
      // `@import "…" reference` is the shorthand of `@reference "…"`.
      if rest.to_lower() == "reference" {
        reference = true
        rest = ""
      }
      return Some({
        id,
        layer,
        supports,
        reference,
        theme_only,
        media: if rest == "" {
          None
        } else {
          Some(rest)
        },
      })
    }
  }
  None
}

///|
fn wrap_import_conditions(
  nodes : Array[CssNode],
  spec : ImportSpec,
  span : SourceSpan,
) -> Array[CssNode] {
  let mut root = nodes
  match spec.layer {
    Some(layer) =>
      root = [AtRule(name="@layer", params=layer, nodes=Some(root), span~)]
    None => ()
  }
  match spec.media {
    Some(media) =>
      root = [AtRule(name="@media", params=media, nodes=Some(root), span~)]
    None => ()
  }
  match spec.supports {
    Some(supports) => {
      let condition = if supports.has_prefix("(") {
        supports
      } else {
        "(\{supports})"
      }
      root = [
        AtRule(name="@supports", params=condition, nodes=Some(root), span~),
      ]
    }
    None => ()
  }
  root
}

///|
fn is_import_at_rule(name : String) -> Bool {
  let lowered = name.to_lower()
  lowered == "@import" || lowered == "@reference"
}

///|
fn contains_import(nodes : ArrayView[CssNode]) -> Bool {
  for node in nodes {
    match node {
      // At-rule names are case insensitive in CSS, so `@IMPORT` counts too.
      AtRule(name~, nodes=None, ..) =>
        if is_import_at_rule(name) {
          return true
        }
      Rule(nodes~, ..) | AtRule(nodes=Some(nodes), ..) | Context(nodes~, ..) =>
        if contains_import(nodes) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn mark_reference_theme(nodes : ArrayView[CssNode]) -> Array[CssNode] {
  nodes.map(fn(node) {
    match node {
      AtRule(name="@theme", params~, nodes~, span~) =>
        AtRule(
          name="@theme",
          params=if trim(params) == "" {
            "reference"
          } else {
            "\{params} reference"
          },
          nodes~,
          span~,
        )
      _ => node
    }
  })
}

///|
/// Whether an imported stylesheet only declares theme blocks.
fn only_theme_nodes(nodes : ArrayView[CssNode]) -> Bool {
  for node in nodes {
    match node {
      AtRule(name="@theme", ..) | Comment(..) => ()
      Context(nodes=children, ..) =>
        if !only_theme_nodes(children) {
          return false
        }
      _ => return false
    }
  }
  true
}

///|
/// Keep only the parts of a referenced stylesheet that outlive the import.
fn keep_reference_nodes(nodes : ArrayView[CssNode]) -> Array[CssNode] {
  let output : Array[CssNode] = []
  for node in nodes {
    match node {
      AtRule(name="@theme" | "@source", ..) => output.push(node)
      Context(values~, nodes=children, span~) => {
        let inner = keep_reference_nodes(children)
        if !inner.is_empty() {
          output.push(Context(values~, nodes=inner, span~))
        }
      }
      _ => ()
    }
  }
  output
}

///|
async fn resolve_imports(
  nodes : ArrayView[CssNode],
  loader : &StylesheetLoader,
  base : String,
  stack : Array[String],
) -> Array[CssNode] raise CompileError {
  let output : Array[CssNode] = []
  for node in nodes {
    match node {
      AtRule(name~, params~, nodes=None, span~) =>
        if !is_import_at_rule(name) {
          output.push(node)
        } else {
          match parse_import_spec(params) {
            None => output.push(node)
            Some(spec) => {
              let loaded = loader.load(spec.id, base)
              if stack.contains(loaded.path) {
                let cycle = stack.copy()
                cycle.push(loaded.path)
                raise ImportCycle(cycle)
              }
              let imported = parse_css(loaded.content)
              let next_stack = stack.copy()
              next_stack.push(loaded.path)
              let resolved = resolve_imports(
                imported,
                loader,
                loaded.base,
                next_stack,
              )
              let is_reference = spec.reference ||
                name.to_lower() == "@reference"
              if spec.theme_only && !only_theme_nodes(resolved) {
                raise InvalidCss(
                  "Files imported with `@import \"\u2026\" theme(reference)` must only contain `@theme` blocks.",
                )
              }
              // A referenced stylesheet only contributes theme variables.
              let resolved = if is_reference {
                keep_reference_nodes(mark_reference_theme(resolved))
              } else {
                resolved
              }
              // The imported file's own directory becomes the base of every
              // `@source` it declares.
              let scoped : Array[CssNode] = [
                Context(values={ "base": loaded.base }, nodes=resolved, span~),
              ]
              for child in wrap_import_conditions(scoped, spec, span) {
                output.push(child)
              }
            }
          }
        }
      Rule(selector~, nodes~, span~) => {
        let children = resolve_imports(nodes, loader, base, stack)
        output.push(Rule(selector~, nodes=children, span~))
      }
      AtRule(name~, params~, nodes=Some(nodes), span~) => {
        let children = resolve_imports(nodes, loader, base, stack)
        output.push(AtRule(name~, params~, nodes=Some(children), span~))
      }
      _ => output.push(node)
    }
  }
  output
}

///|
/// Synchronous counterpart of `resolve_imports`, driving a `SyncStylesheetLoader`.
///
/// Behaves identically to `resolve_imports`; kept in lockstep with it. Used by
/// `compile_sync` so hosts without an async runtime (e.g. wasm-gc) can still
/// resolve in-memory `@import`s.
fn resolve_imports_sync(
  nodes : ArrayView[CssNode],
  loader : &SyncStylesheetLoader,
  base : String,
  stack : Array[String],
) -> Array[CssNode] raise CompileError {
  let output : Array[CssNode] = []
  for node in nodes {
    match node {
      AtRule(name~, params~, nodes=None, span~) =>
        if !is_import_at_rule(name) {
          output.push(node)
        } else {
          match parse_import_spec(params) {
            None => output.push(node)
            Some(spec) => {
              let loaded = loader.load(spec.id, base)
              if stack.contains(loaded.path) {
                let cycle = stack.copy()
                cycle.push(loaded.path)
                raise ImportCycle(cycle)
              }
              let imported = parse_css(loaded.content)
              let next_stack = stack.copy()
              next_stack.push(loaded.path)
              let resolved = resolve_imports_sync(
                imported,
                loader,
                loaded.base,
                next_stack,
              )
              let is_reference = spec.reference ||
                name.to_lower() == "@reference"
              if spec.theme_only && !only_theme_nodes(resolved) {
                raise InvalidCss(
                  "Files imported with `@import \"…\" theme(reference)` must only contain `@theme` blocks.",
                )
              }
              let resolved = if is_reference {
                keep_reference_nodes(mark_reference_theme(resolved))
              } else {
                resolved
              }
              let scoped : Array[CssNode] = [
                Context(values={ "base": loaded.base }, nodes=resolved, span~),
              ]
              for child in wrap_import_conditions(scoped, spec, span) {
                output.push(child)
              }
            }
          }
        }
      Rule(selector~, nodes~, span~) => {
        let children = resolve_imports_sync(nodes, loader, base, stack)
        output.push(Rule(selector~, nodes=children, span~))
      }
      AtRule(name~, params~, nodes=Some(nodes), span~) => {
        let children = resolve_imports_sync(nodes, loader, base, stack)
        output.push(AtRule(name~, params~, nodes=Some(children), span~))
      }
      _ => output.push(node)
    }
  }
  output
}
