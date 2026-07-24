///|
/// Rewrite compiled candidate nodes so that they read as nested content of the
/// rule the `@apply` lives in.
///
/// The candidate selector becomes `&`, and an at-rule that wraps a single rule
/// is turned inside out so the nesting matches what upstream produces for
/// variants such as `hover`, which pair a selector with a media query.
fn relative_candidate_nodes(
  nodes : ArrayView[CssNode],
  selector : String,
) -> Array[CssNode] {
  let output : Array[CssNode] = []
  for
    node in strip_self_rules(
      replace_candidate_selector_nodes(nodes, selector, "&"),
    ) {
    output.push(hoist_single_rule(node))
  }
  output
}

///|
/// Drop `&` rules, which only exist because compiled candidates always start
/// from a class selector.
fn strip_self_rules(nodes : ArrayView[CssNode]) -> Array[CssNode] {
  let output : Array[CssNode] = []
  for node in nodes {
    match node {
      Rule(selector="&", nodes=children, ..) =>
        for child in strip_self_rules(children) {
          output.push(child)
        }
      Rule(selector~, nodes=children, span~) =>
        output.push(Rule(selector~, nodes=strip_self_rules(children), span~))
      AtRule(name~, params~, nodes=Some(children), span~) =>
        output.push(
          AtRule(name~, params~, nodes=Some(strip_self_rules(children)), span~),
        )
      Context(values~, nodes=children, span~) =>
        output.push(Context(values~, nodes=strip_self_rules(children), span~))
      _ => output.push(node)
    }
  }
  output
}

///|
fn hoist_single_rule(node : CssNode) -> CssNode {
  match node {
    AtRule(name~, params~, nodes=Some(children), span~) => {
      let hoisted = children.map(hoist_single_rule)
      match hoisted {
        [Rule(selector=inner_selector, nodes=inner_nodes, span=inner_span)] =>
          Rule(
            selector=inner_selector,
            nodes=[AtRule(name~, params~, nodes=Some(inner_nodes), span~)],
            span=inner_span,
          )
        _ => AtRule(name~, params~, nodes=Some(hoisted), span~)
      }
    }
    Rule(selector~, nodes=children, span~) =>
      Rule(selector~, nodes=children.map(hoist_single_rule), span~)
    _ => node
  }
}

///|
/// Compile one `@apply` candidate into nodes relative to the surrounding rule.
fn nodes_for_apply(
  theme : Map[String, String],
  custom_utilities : Map[String, Array[CssNode]],
  functional_utilities : Map[String, Array[CssNode]],
  custom_variants : Map[String, CustomVariantTemplate],
  raw : String,
  span : SourceSpan,
) -> (Array[CssNode], RenderedCandidate) raise CompileError {
  guard render_candidate(
      theme, custom_utilities, functional_utilities, custom_variants, raw,
    )
    is Some(rendered) else {
    raise InvalidApplyCandidate(raw)
  }
  let relative = relative_candidate_nodes(
    rendered.nodes,
    ".\{escape_class_name(raw)}",
  )
  let output : Array[CssNode] = []
  for node in relative {
    match node {
      // The candidate rule itself disappears; its declarations belong to the
      // rule that used `@apply`.
      Rule(selector="&", nodes=children, ..) =>
        for child in children {
          output.push(child)
        }
      _ => output.push(node)
    }
  }
  ignore(span)
  (output, rendered)
}

///|
/// Expand all candidates of one `@apply` directive, in build order.
fn nodes_for_apply_directive(
  theme : Map[String, String],
  custom_utilities : Map[String, Array[CssNode]],
  functional_utilities : Map[String, Array[CssNode]],
  custom_variants : Map[String, CustomVariantTemplate],
  params : String,
  span : SourceSpan,
) -> Array[CssNode] raise CompileError {
  let compiled : Array[(Array[CssNode], RenderedCandidate)] = []
  for candidate in params.split(" ") {
    let raw = trim(candidate.to_owned())
    if raw == "" {
      continue
    }
    compiled.push(
      nodes_for_apply(
        theme, custom_utilities, functional_utilities, custom_variants, raw, span,
      ),
    )
  }
  compiled.sort_by(fn(a, b) {
    let (_, left) = a
    let (_, right) = b
    compare_rendered_candidates(left, right)
  })
  let output : Array[CssNode] = []
  for entry in compiled {
    let (nodes, _) = entry
    for node in nodes {
      output.push(node)
    }
  }
  output
}

///|
fn substitute_apply(
  nodes : ArrayView[CssNode],
  theme : Map[String, String],
  custom_utilities : Map[String, Array[CssNode]],
  functional_utilities : Map[String, Array[CssNode]],
  custom_variants : Map[String, CustomVariantTemplate],
) -> (Array[CssNode], Bool) raise CompileError {
  let output : Array[CssNode] = []
  let mut changed = false
  for node in nodes {
    match node {
      AtRule(name="@apply", params~, nodes=None, span~) => {
        changed = true
        for
          applied in nodes_for_apply_directive(
            theme, custom_utilities, functional_utilities, custom_variants, params,
            span,
          ) {
          output.push(applied)
        }
      }
      Rule(selector~, nodes~, span~) => {
        let (children, child_changed) = substitute_apply(
          nodes, theme, custom_utilities, functional_utilities, custom_variants,
        )
        changed = changed || child_changed
        output.push(Rule(selector~, nodes=children, span~))
      }
      AtRule(name~, params~, nodes=Some(nodes), span~) => {
        let (children, child_changed) = substitute_apply(
          nodes, theme, custom_utilities, functional_utilities, custom_variants,
        )
        changed = changed || child_changed
        output.push(AtRule(name~, params~, nodes=Some(children), span~))
      }
      Context(values~, nodes=children, span~) => {
        let (inner, inner_changed) = substitute_apply(
          children, theme, custom_utilities, functional_utilities, custom_variants,
        )
        changed = changed || inner_changed
        output.push(Context(values~, nodes=inner, span~))
      }
      _ => output.push(node)
    }
  }
  (output, changed)
}
