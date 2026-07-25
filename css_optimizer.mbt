///|
/// Resolve a nested selector against the selector of its parent rule.
///
/// A selector list has to become a single compound before it can be nested,
/// which upstream does with `:is(…)`.
fn nested_selector(child : String, parent : String) -> String {
  let reference = if has_top_level_comma(parent) {
    ":is(\{parent})"
  } else {
    parent
  }
  if child.contains("&") {
    replace_all(child, "&", reference)
  } else {
    "\{reference} \{child}"
  }
}

///|
fn node_is_declaration(node : CssNode) -> Bool {
  match node {
    Declaration(..) => true
    _ => false
  }
}

///|
/// Flatten nested rules the way the upstream optimizer does.
///
/// A rule that declares nothing itself is dissolved into its children: nested
/// selectors merge with the parent selector and nested at-rules move above it.
/// A rule that does declare something keeps its nested children as authored.
fn flatten_css_nesting(nodes : ArrayView[CssNode]) -> Array[CssNode] {
  let output : Array[CssNode] = []
  for node in nodes {
    match node {
      Rule(selector="&", nodes=children, ..) =>
        for flattened in flatten_css_nesting(children) {
          output.push(flattened)
        }
      Rule(selector~, nodes=children, span~) =>
        for flattened in flatten_css_rule(selector, children, span) {
          output.push(flattened)
        }
      AtRule(name~, params~, nodes=Some(children), span~) => {
        let inner = flatten_css_nesting(children)
        if !inner.is_empty() {
          output.push(AtRule(name~, params~, nodes=Some(inner), span~))
        }
      }
      Context(values~, nodes=children, span~) =>
        output.push(
          Context(values~, nodes=flatten_css_nesting(children), span~),
        )
      AtRoot(nodes=children, span~) =>
        output.push(AtRoot(nodes=flatten_css_nesting(children), span~))
      _ => output.push(node)
    }
  }
  output
}

///|
/// Drop declarations that a later identical declaration repeats.
///
/// Upstream keeps the last occurrence, so the earlier copy is the one removed.
fn dedupe_declarations(nodes : ArrayView[CssNode]) -> Array[CssNode] {
  let output : Array[CssNode] = []
  for index, node in nodes {
    match node {
      Declaration(name~, value~, important~, ..) => {
        let mut repeated = false
        for later in (index + 1)..<nodes.length() {
          match nodes[later] {
            Declaration(
              name=later_name,
              value=later_value,
              important=later_important,
              ..
            ) =>
              if later_name == name &&
                later_value == value &&
                later_important == important {
                repeated = true
                break
              }
            _ => ()
          }
        }
        if !repeated {
          output.push(node)
        }
      }
      _ => output.push(node)
    }
  }
  output
}

///|
/// Merge neighbouring rules and at-rules that describe the same thing.
///
/// Stacked at-rule variants produce one wrapper per candidate, and repeated
/// selectors produce one rule per source block; upstream collapses each run.
fn merge_adjacent_at_rules(nodes : ArrayView[CssNode]) -> Array[CssNode] {
  let output : Array[CssNode] = []
  for node in nodes {
    match node {
      AtRule(name~, params~, nodes=Some(children), span~) => {
        let merged = merge_adjacent_at_rules(children)
        match output.last() {
          Some(
            AtRule(
              name=previous_name,
              params=previous_params,
              nodes=Some(previous_children),
              ..
            )
          ) if previous_name == name && previous_params == params =>
            // The wrapper already in `output` keeps its own span, and its child
            // array is extended in place, so a run of K wrappers costs one walk
            // rather than one per member.
            append_merged(previous_children, merged)
          _ =>
            output.push(
              AtRule(
                name~,
                params~,
                nodes=Some(dedupe_declarations(merged)),
                span~,
              ),
            )
        }
      }
      Rule(selector~, nodes=children, span~) => {
        let merged = merge_adjacent_at_rules(children)
        match output.last() {
          Some(Rule(selector=previous_selector, nodes=previous_children, ..)) if previous_selector ==
            selector => {
            append_merged(previous_children, merged)
            // Deduplication spans the whole run: a declaration repeated by a
            // later member removes the earlier copy.
            rededuplicate(previous_children)
          }
          _ =>
            output.push(
              Rule(selector~, nodes=dedupe_declarations(merged), span~),
            )
        }
      }
      Context(values~, nodes=children, span~) =>
        output.push(
          Context(values~, nodes=merge_adjacent_at_rules(children), span~),
        )
      _ => output.push(node)
    }
  }
  output
}

///|
/// Replace `nodes` with its deduplicated form, in place.
fn rededuplicate(nodes : Array[CssNode]) -> Unit {
  let deduped = dedupe_declarations(nodes[:])
  nodes.clear()
  nodes.append(deduped)
}

///|
/// Append one already-merged sibling list onto another, in place.
///
/// Both sides are internally merged, so concatenating them can only create a
/// single new adjacency — the junction — and merging that junction can only
/// create one more, one level down. The previous implementation instead copied
/// the accumulated children and re-ran `merge_adjacent_at_rules` over the whole
/// concatenation for *every* additional sibling, re-walking (and re-merging,
/// re-deduplicating) the entire subtree to discover that one boundary: O(K²)
/// walks for a run of K wrappers, which grows with candidate count.
fn append_merged(
  target : Array[CssNode],
  addition : ArrayView[CssNode],
) -> Unit {
  for node in addition {
    let mut absorbed = false
    match (target.last(), node) {
      (
        Some(
          AtRule(
            name=previous_name,
            params=previous_params,
            nodes=Some(previous_children),
            ..
          )
        ),
        AtRule(name~, params~, nodes=Some(children), ..),
      ) =>
        if previous_name == name && previous_params == params {
          append_merged(previous_children, children)
          absorbed = true
        }
      (
        Some(Rule(selector=previous_selector, nodes=previous_children, ..)),
        Rule(selector~, nodes=children, ..),
      ) =>
        if previous_selector == selector {
          append_merged(previous_children, children)
          rededuplicate(previous_children)
          absorbed = true
        }
      _ => ()
    }
    if !absorbed {
      target.push(node)
    }
  }
}

///|
fn flatten_css_rule(
  selector : String,
  children : ArrayView[CssNode],
  span : SourceSpan,
) -> Array[CssNode] {
  if children.is_empty() {
    return []
  }
  // Once a rule declares something, upstream leaves everything below it alone:
  // nested content cannot move out without duplicating this rule.
  if children.iter().any(node_is_declaration) {
    return [Rule(selector~, nodes=children.to_owned(), span~)]
  }
  let output : Array[CssNode] = []
  for child in children {
    match child {
      Rule(selector=child_selector, nodes=grandchildren, span=child_span) =>
        for
          flattened in flatten_css_rule(
            nested_selector(child_selector, selector),
            grandchildren,
            child_span,
          ) {
          output.push(flattened)
        }
      AtRule(name~, params~, nodes=Some(grandchildren), span=child_span) => {
        let inner = flatten_css_rule(selector, grandchildren, child_span)
        if !inner.is_empty() {
          output.push(
            AtRule(name~, params~, nodes=Some(inner), span=child_span),
          )
        }
      }
      _ => output.push(child)
    }
  }
  output
}

///|
let color_mix_supports = "(color: color-mix(in lab, red, red))"

///|
/// Replace `var(--x)` references with their raw theme literal (dropping any
/// fallback), for building the sRGB `color-mix()` compatibility value.
fn resolve_theme_var_literals(
  nodes : ArrayView[ValueNode],
  theme : Map[String, String],
) -> Array[ValueNode] {
  let output : Array[ValueNode] = []
  for node in nodes {
    match node {
      ValueFunction("var", children) => {
        let mut name = ""
        for child in children {
          if child is ValueWord(word) {
            name = word
            break
          }
        }
        match theme.get(name) {
          Some(literal) if !literal.contains("var(") =>
            output.push(ValueWord(literal))
          _ =>
            output.push(
              ValueFunction("var", resolve_theme_var_literals(children, theme)),
            )
        }
      }
      ValueFunction(other, children) =>
        output.push(
          ValueFunction(other, resolve_theme_var_literals(children, theme)),
        )
      _ => output.push(node)
    }
  }
  output
}

///|
/// Rewrite `color-mix(in oklab|oklch, …)` to its sRGB compatibility form:
/// resolve theme variables to literals and switch the interpolation space to
/// `srgb`. Returns `None` when the value has no oklab/oklch `color-mix()`.
fn color_mix_fallback_nodes(
  nodes : ArrayView[ValueNode],
  theme : Map[String, String],
) -> (Array[ValueNode], Bool) {
  let output : Array[ValueNode] = []
  let mut changed = false
  for node in nodes {
    match node {
      ValueFunction("color-mix", children) => {
        let resolved = resolve_theme_var_literals(children, theme)
        let (inner, _) = color_mix_fallback_nodes(resolved, theme)
        // A `color-mix()` involving `currentColor` cannot be reduced to a static
        // colour, and an sRGB `color-mix()` still needs `color-mix` support, so
        // the fallback drops the mix and keeps the bare `currentColor` token.
        let mut current_color : String? = None
        for child in inner {
          if child is ValueWord(word) && word.to_lower() == "currentcolor" {
            current_color = Some(word)
            break
          }
        }
        match current_color {
          Some(word) => {
            changed = true
            output.push(ValueWord(word))
          }
          None => {
            // Switch the first `oklab`/`oklch` color-space keyword to `srgb`.
            let swapped : Array[ValueNode] = []
            let mut did_swap = false
            for child in inner {
              if !did_swap &&
                (child is ValueWord("oklab") || child is ValueWord("oklch")) {
                swapped.push(ValueWord("srgb"))
                did_swap = true
              } else {
                swapped.push(child)
              }
            }
            changed = changed || did_swap
            output.push(ValueFunction("color-mix", swapped))
          }
        }
      }
      ValueFunction(name, children) => {
        let (inner, inner_changed) = color_mix_fallback_nodes(children, theme)
        changed = changed || inner_changed
        output.push(ValueFunction(name, inner))
      }
      _ => output.push(node)
    }
  }
  (output, changed)
}

///|
/// Build the plain sRGB fallback string for a value containing an oklab/oklch
/// `color-mix()`, or `None` when there is nothing to polyfill.
fn color_mix_fallback_value(
  value : String,
  theme : Map[String, String],
) -> String? {
  if !(value.contains("color-mix(in oklab") ||
    value.contains("color-mix(in oklch")) {
    return None
  }
  let (rebuilt, changed) = color_mix_fallback_nodes(parse_value(value), theme)
  if !changed {
    return None
  }
  Some(render_value(rebuilt))
}

///|
/// Add the `color-mix()` compatibility fallback for author declarations: a
/// plain sRGB value followed by the modern value inside
/// `@supports (color: color-mix(in lab, red, red))`.
///
/// Declarations already inside that `@supports` block (the modern branch of an
/// existing fallback, e.g. utility output) are left untouched.
fn add_color_mix_fallback(
  nodes : ArrayView[CssNode],
  theme : Map[String, String],
  inside : Bool,
) -> Array[CssNode] {
  let output : Array[CssNode] = []
  for node in nodes {
    match node {
      AtRule(
        name="@supports",
        params=color_mix_supports,
        nodes=Some(children),
        span~
      ) =>
        output.push(
          AtRule(
            name="@supports",
            params=color_mix_supports,
            nodes=Some(add_color_mix_fallback(children, theme, true)),
            span~,
          ),
        )
      Declaration(name~, value~, important~, span~) => {
        let fallback_value = if inside {
          None
        } else {
          color_mix_fallback_value(value, theme)
        }
        match fallback_value {
          Some(fallback) => {
            output.push(Declaration(name~, value=fallback, important~, span~))
            output.push(
              AtRule(
                name="@supports",
                params=color_mix_supports,
                nodes=Some([Declaration(name~, value~, important~, span~)]),
                span~,
              ),
            )
          }
          None => output.push(node)
        }
      }
      Rule(selector~, nodes=children, span~) =>
        output.push(
          Rule(
            selector~,
            nodes=add_color_mix_fallback(children, theme, inside),
            span~,
          ),
        )
      AtRule(name~, params~, nodes=Some(children), span~) =>
        output.push(
          AtRule(
            name~,
            params~,
            nodes=Some(add_color_mix_fallback(children, theme, inside)),
            span~,
          ),
        )
      Context(values~, nodes=children, span~) =>
        output.push(
          Context(
            values~,
            nodes=add_color_mix_fallback(children, theme, inside),
            span~,
          ),
        )
      _ => output.push(node)
    }
  }
  output
}

///|
/// Remove the `color-mix()` compatibility fallback.
///
/// Each fallback is a plain declaration followed by the modern value inside
/// `@supports (color: color-mix(in lab, red, red))`; dropping the polyfill
/// keeps only the modern value.
fn strip_color_mix_fallback(nodes : ArrayView[CssNode]) -> Array[CssNode] {
  let output : Array[CssNode] = []
  for node in nodes {
    match node {
      AtRule(
        name="@supports",
        params="(color: color-mix(in lab, red, red))",
        nodes=Some(children),
        ..
      ) =>
        for child in children {
          match child {
            Declaration(name~, ..) => {
              // Drop the fallback this modern value replaces.
              let mut index = output.length() - 1
              while index >= 0 {
                match output[index] {
                  Declaration(name=previous, ..) if previous == name => {
                    output.remove(index) |> ignore
                    break
                  }
                  _ => index -= 1
                }
              }
            }
            _ => ()
          }
          output.push(child)
        }
      AtRule(name~, params~, nodes=Some(children), span~) =>
        output.push(
          AtRule(
            name~,
            params~,
            nodes=Some(strip_color_mix_fallback(children)),
            span~,
          ),
        )
      Rule(selector~, nodes=children, span~) =>
        output.push(
          Rule(selector~, nodes=strip_color_mix_fallback(children), span~),
        )
      Context(values~, nodes=children, span~) =>
        output.push(
          Context(values~, nodes=strip_color_mix_fallback(children), span~),
        )
      _ => output.push(node)
    }
  }
  output
}
