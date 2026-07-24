///|
/// Replace `@variant <variant> { … }` blocks with the variant applied to their
/// body.
///
/// The body is compiled as if it lived inside a rule with the selector `&`. If
/// the variant leaves that selector alone the wrapper disappears; otherwise the
/// rewritten selector is anchored with `:scope`.
fn substitute_at_variant(
  nodes : ArrayView[CssNode],
  theme : Map[String, String],
  custom_variants : Map[String, CustomVariantTemplate],
) -> (Array[CssNode], Bool) raise CompileError {
  let output : Array[CssNode] = []
  let mut changed = false
  for node in nodes {
    match node {
      AtRule(name="@variant", params~, nodes=Some(children), span~) => {
        changed = true
        let (body, _) = substitute_at_variant(children, theme, custom_variants)
        for
          expanded in expand_at_variant(
            trim(params),
            body,
            theme,
            custom_variants,
            span,
          ) {
          output.push(expanded)
        }
      }
      Rule(selector~, nodes=children, span~) => {
        let (inner, inner_changed) = substitute_at_variant(
          children, theme, custom_variants,
        )
        changed = changed || inner_changed
        output.push(Rule(selector~, nodes=inner, span~))
      }
      AtRule(name~, params~, nodes=Some(children), span~) => {
        let (inner, inner_changed) = substitute_at_variant(
          children, theme, custom_variants,
        )
        changed = changed || inner_changed
        output.push(AtRule(name~, params~, nodes=Some(inner), span~))
      }
      Context(values~, nodes=children, span~) => {
        let (inner, inner_changed) = substitute_at_variant(
          children, theme, custom_variants,
        )
        changed = changed || inner_changed
        output.push(Context(values~, nodes=inner, span~))
      }
      _ => output.push(node)
    }
  }
  (output, changed)
}

///|
fn expand_at_variant(
  params : String,
  body : Array[CssNode],
  theme : Map[String, String],
  custom_variants : Map[String, CustomVariantTemplate],
  span : SourceSpan,
) -> Array[CssNode] raise CompileError {
  if params == "" {
    raise InvalidCss("Cannot use `@variant` without a variant")
  }
  let output : Array[CssNode] = []
  // A comma separated list repeats the body once per variant.
  for branch in split_top_level(params, ',') {
    let stack = trim(branch)
    if stack == "" {
      raise InvalidCss("Cannot use `@variant` with empty variant")
    }
    let mut current : Array[CssNode] = [
      Rule(selector="&", nodes=body.copy(), span~),
    ]
    let mut selector = "&"
    for variant in split_variants(stack) {
      guard apply_variant_to_nodes(
          variant,
          current,
          selector,
          theme,
          custom_variants,
          [],
        )
        is Some((next_nodes, next_selector)) else {
        raise InvalidCss(
          "Cannot use `@variant` with unknown variant: \{variant}",
        )
      }
      current = next_nodes
      selector = next_selector
    }
    for
      node in replace_candidate_selector_nodes(
        strip_self_rules(current),
        "&",
        ":scope",
      ) {
      output.push(node)
    }
  }
  output
}
