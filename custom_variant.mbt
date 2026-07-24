///|
/// Variant names accepted by `@custom-variant`, matching the upstream grammar.
fn is_valid_variant_name(name : String) -> Bool {
  let body = if name.has_prefix("@") { name[1:].to_owned() } else { name }
  if body == "" {
    return false
  }
  let first = body[0]
  if !((first >= 'a' && first <= 'z') || (first >= '0' && first <= '9')) {
    return false
  }
  for character in body {
    if !((character >= 'a' && character <= 'z') ||
      (character >= 'A' && character <= 'Z') ||
      (character >= '0' && character <= '9') ||
      character == '_' ||
      character == '-') {
      return false
    }
  }
  !body.has_suffix("_") && !body.has_suffix("-")
}

///|
/// Build the template of a `@custom-variant name (…)` selector list.
///
/// Entries that start with `@` become at-rules wrapping `@slot`, and the
/// remaining selectors are joined into a single rule, as upstream does.
fn custom_variant_selector_template(
  name : String,
  raw : String,
) -> CustomVariantTemplate raise CompileError {
  let entries = split_top_level(raw, ',').map(trim)
  if entries.is_empty() || entries.contains("") {
    raise InvalidCss("`@custom-variant \{name} (\{raw})` selector is invalid.")
  }
  let selectors = entries.filter(fn(entry) { !entry.has_prefix("@") })
  let at_rules = entries.filter(fn(entry) { entry.has_prefix("@") })
  if at_rules.is_empty() {
    return CustomVariantSelector(selectors.join(", "))
  }
  let span : SourceSpan = { start: 0, end: 0 }
  let slot : CssNode = AtRule(name="@slot", params="", nodes=None, span~)
  let template : Array[CssNode] = []
  if !selectors.is_empty() {
    template.push(Rule(selector=selectors.join(", "), nodes=[slot], span~))
  }
  for entry in at_rules {
    let (at_name, params) = match entry.split_once(" ") {
      Some((at_name, params)) => (at_name.to_owned(), trim(params.to_owned()))
      None => (entry, "")
    }
    template.push(AtRule(name=at_name, params~, nodes=Some([slot]), span~))
  }
  CustomVariantNodes(template)
}

///|
fn parse_custom_variants(
  nodes : ArrayView[CssNode],
) -> Map[String, CustomVariantTemplate] raise CompileError {
  let variants : Map[String, CustomVariantTemplate] = Map([])
  for node in nodes {
    match node {
      AtRule(name="@custom-variant", params~, nodes=None, ..) => {
        let (name, raw_selector) = match params.split_once(" ") {
          Some((name, rest)) => (trim(name.to_owned()), trim(rest.to_owned()))
          None => (trim(params), "")
        }
        if !is_valid_variant_name(name) {
          raise InvalidCss(
            "`@custom-variant \{name}` defines an invalid variant name.",
          )
        }
        if raw_selector == "" {
          raise InvalidCss("`@custom-variant \{name}` has no selector or body.")
        }
        let selector = if raw_selector.has_prefix("(") &&
          raw_selector.has_suffix(")") {
          raw_selector[1:raw_selector.length() - 1].to_owned()
        } else {
          raw_selector
        }
        variants[name] = custom_variant_selector_template(name, selector)
      }
      AtRule(name="@custom-variant", params~, nodes=Some(children), ..) => {
        let variant_name = trim(params)
        if variant_name.contains(" ") {
          raise InvalidCss(
            "`@custom-variant \{variant_name}` cannot have both a selector and a body.",
          )
        }
        if !is_valid_variant_name(variant_name) {
          raise InvalidCss(
            "`@custom-variant \{variant_name}` defines an invalid variant name.",
          )
        }
        if children.is_empty() {
          raise InvalidCss("`@custom-variant \{variant_name}` is empty.")
        }
        variants[variant_name] = CustomVariantNodes(children.copy())
      }
      Rule(nodes~, ..) | AtRule(nodes=Some(nodes), ..) | Context(nodes~, ..) => {
        let nested = parse_custom_variants(nodes)
        for name, selector in nested {
          variants[name] = selector
        }
      }
      _ => ()
    }
  }
  variants
}

///|
fn remove_custom_variant_nodes(
  nodes : ArrayView[CssNode],
) -> (Array[CssNode], Bool) {
  let output : Array[CssNode] = []
  let mut changed = false
  for node in nodes {
    match node {
      AtRule(name="@custom-variant", ..) => changed = true
      Rule(selector~, nodes~, span~) => {
        let (children, child_changed) = remove_custom_variant_nodes(nodes)
        changed = changed || child_changed
        output.push(Rule(selector~, nodes=children, span~))
      }
      AtRule(name~, params~, nodes=Some(nodes), span~) => {
        let (children, child_changed) = remove_custom_variant_nodes(nodes)
        changed = changed || child_changed
        output.push(AtRule(name~, params~, nodes=Some(children), span~))
      }
      Context(values~, nodes=children, span~) => {
        let (inner, inner_changed) = remove_custom_variant_nodes(children)
        changed = changed || inner_changed
        output.push(Context(values~, nodes=inner, span~))
      }
      _ => output.push(node)
    }
  }
  (output, changed)
}
