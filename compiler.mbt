///|
/// Remove `@theme` blocks from a stylesheet, at any depth.
fn remove_theme_nodes_deep(nodes : ArrayView[CssNode]) -> Array[CssNode] {
  let output : Array[CssNode] = []
  for node in nodes {
    match node {
      AtRule(name="@theme", ..) => ()
      AtRule(name~, params~, nodes=Some(children), span~) =>
        output.push(
          AtRule(
            name~,
            params~,
            nodes=Some(remove_theme_nodes_deep(children)),
            span~,
          ),
        )
      Rule(selector~, nodes=children, span~) =>
        output.push(
          Rule(selector~, nodes=remove_theme_nodes_deep(children), span~),
        )
      Context(values~, nodes=children, span~) =>
        output.push(
          Context(values~, nodes=remove_theme_nodes_deep(children), span~),
        )
      _ => output.push(node)
    }
  }
  output
}

///|
/// Collect the distinct texts that follow a literal `var(` in `css`, sorted.
///
/// The usage test these feed is a *prefix* test — a theme variable counts as used
/// when the CSS contains `var(<name>`, so `var(--text-sm--line-height)` also marks
/// `--text-sm` used. Tokens are therefore kept whole and probed with
/// `sorted_has_prefix` instead of compared for equality, which preserves that
/// behaviour while replacing one whole-CSS search per theme variable (400+ on a
/// full import) with a single pass.
fn var_reference_tokens(css : String) -> Array[String] {
  let seen : Map[String, Unit] = Map([])
  let length = css.length()
  let mut pos = 0
  while pos < length {
    guard css[pos:].find("var(") is Some(offset) else { break }
    let start = pos + offset + 4
    let mut end = start
    while end < length {
      let character = css[end]
      if character == ')' ||
        character == ',' ||
        character == ' ' ||
        character == '\n' ||
        character == '\t' ||
        character == '\r' {
        break
      }
      end += 1
    }
    if end > start {
      seen[css[start:end].to_owned()] = ()
    }
    pos = start
  }
  let tokens = seen.keys().to_array()
  tokens.sort_by(lexical_compare)
  tokens
}

///|
/// Whether any token in the sorted `tokens` starts with `prefix`.
///
/// Strings sharing a prefix are contiguous in lexicographic order and are the
/// first entries at or after the prefix itself, so one binary search decides it.
fn sorted_has_prefix(tokens : ArrayView[String], prefix : String) -> Bool {
  let mut low = 0
  let mut high = tokens.length()
  while low < high {
    let middle = (low + high) / 2
    if lexical_compare(tokens[middle], prefix) < 0 {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low < tokens.length() && tokens[low].has_prefix(prefix)
}

///|
/// Build the `:root, :host` rule that carries the theme variables in use.
fn theme_rule_nodes(
  theme : Map[String, String],
  generated_css : String,
) -> Array[CssNode] {
  if theme.is_empty() {
    return []
  }
  // Precompute each non-meta theme variable's `var(<name>` search string ONCE.
  // Previously the fixed-point below recomputed `theme_variable_name` and
  // re-interpolated the search string for every (used × dependency) pair on every
  // iteration — O(V²) throwaway string allocations for a full theme.
  let names : Array[String] = []
  let variables : Array[String] = []
  let searches : Array[String] = []
  for name, _ in theme {
    if name.has_prefix(theme_meta_prefix) {
      continue
    }
    names.push(name)
    let variable = theme_variable_name(theme, name)
    variables.push(variable)
    searches.push("var(" + variable)
  }
  let referenced = var_reference_tokens(generated_css)
  let used : Map[String, Unit] = Map([])
  for i in 0..<names.length() {
    if theme.contains(theme_meta("static", names[i])) ||
      sorted_has_prefix(referenced, variables[i]) {
      used[names[i]] = ()
    }
  }
  // A used variable may reference another one, which then has to be emitted
  // as well. Most theme values contain no `var()` at all, so the cheap check
  // skips the per-dependency scan entirely for them.
  for ;; {
    let additions : Array[String] = []
    for name, _ in used {
      match theme.get(name) {
        Some(value) =>
          if value.contains("var(") {
            for i in 0..<names.length() {
              let dependency = names[i]
              if !used.contains(dependency) &&
                !additions.contains(dependency) &&
                value.contains(searches[i]) {
                additions.push(dependency)
              }
            }
          }
        None => ()
      }
    }
    if additions.is_empty() {
      break
    }
    for name in additions {
      used[name] = ()
    }
  }
  let span : SourceSpan = { start: 0, end: 0 }
  let declarations : Array[CssNode] = []
  for name, value in theme {
    if name.has_prefix(theme_meta_prefix) ||
      theme.contains(theme_meta("inline", name)) ||
      theme.contains(theme_meta("reference", name)) {
      continue
    }
    // A theme value that resolves to `initial` is treated as unset: it is not
    // emitted to `:root`, while `var(name, fallback)` references elsewhere still
    // fall back. This mirrors upstream's deprecated inline-reference defaults.
    if trim(value) == "initial" {
      continue
    }
    if used.contains(name) {
      declarations.push(
        Declaration(
          name=theme_variable_name(theme, name),
          value~,
          important=false,
          span~,
        ),
      )
    }
  }
  if declarations.is_empty() {
    return []
  }
  [Rule(selector=":root, :host", nodes=declarations, span~)]
}

///|
/// Parse a Tailwind CSS v4 stylesheet and return a reusable compiler.
///
/// Resolves `@import`s through the async `options.loader`. Hosts without an
/// async runtime (e.g. wasm-gc) should use `compile_sync` instead.
pub async fn compile(
  css : String,
  options? : CompileOptions = CompileOptions::new(),
) -> Compiler {
  let ast = parse_css(css)
  let had_imports = contains_import(ast)
  let resolved_ast = if had_imports {
    guard options.loader is Some(loader) else {
      raise MissingStylesheetLoader("@import requires a stylesheet loader")
    }
    resolve_imports(ast, loader, options.base, [])
  } else {
    ast
  }
  compile_from_ast(resolved_ast, css, had_imports, options)
}

///|
/// Synchronous variant of `compile`, resolving `@import`s through
/// `options.sync_loader`.
///
/// This is the entry point for hosts that cannot drive an async runtime, most
/// notably the wasm-gc backend. Behaviour is otherwise identical to `compile`;
/// `MemoryStylesheetLoader` implements the required `SyncStylesheetLoader`.
pub fn compile_sync(
  css : String,
  options? : CompileOptions = CompileOptions::new(),
) -> Compiler raise CompileError {
  let ast = parse_css(css)
  let had_imports = contains_import(ast)
  let resolved_ast = if had_imports {
    guard options.sync_loader is Some(loader) else {
      raise MissingStylesheetLoader("@import requires a stylesheet loader")
    }
    resolve_imports_sync(ast, loader, options.base, [])
  } else {
    ast
  }
  compile_from_ast(resolved_ast, css, had_imports, options)
}

///|
/// Shared, fully synchronous tail of `compile`/`compile_sync`: everything after
/// `@import` resolution. `resolved_ast` has had its imports inlined, `source_css`
/// is the stylesheet as authored, and `had_imports` says whether resolution
/// changed it (in which case echoing `source_css` back is not equivalent).
fn compile_from_ast(
  resolved_ast : Array[CssNode],
  source_css : String,
  had_imports : Bool,
  options : CompileOptions,
) -> Compiler raise CompileError {
  reject_javascript_directives(resolved_ast)
  let theme = parse_theme(resolved_ast)
  // Theme values may themselves call compile-time functions (e.g. upstream's
  // `--default-font-family: --theme(--font-sans, initial)`). Resolve them so the
  // emitted `:root` declarations never leak a `--theme()`/`--spacing()` call.
  resolve_theme_value_functions(theme)
  let (function_ast, did_functions) = substitute_css_functions(
    resolved_ast, theme,
  )
  let source_directives = parse_source_directives(function_ast, options.base)
  let (without_sources, did_sources) = remove_source_nodes(function_ast)
  let (custom_utilities, functional_utilities) = parse_custom_utilities(
    without_sources,
  )
  let custom_variants = parse_custom_variants(without_sources)
  let (custom_utilities, functional_utilities) = resolve_custom_utility_bodies(
    custom_utilities, functional_utilities, theme, custom_variants,
  )
  let (without_utilities, did_custom_utility) = remove_custom_utility_nodes(
    without_sources,
  )
  let (without_custom, did_custom_variant) = remove_custom_variant_nodes(
    without_utilities,
  )
  let (applied_ast, did_apply) = substitute_apply(
    without_custom, theme, custom_utilities, functional_utilities, custom_variants,
  )
  let (applied_ast, did_at_variant) = substitute_at_variant(
    applied_ast, theme, custom_variants,
  )
  let flattened_ast = merge_adjacent_at_rules(flatten_css_nesting(applied_ast))
  // Comparing the two trees directly replaces rendering both of them to strings
  // just to diff them. `flatten_css_nesting`/`merge_adjacent_at_rules` only ever
  // reuse the spans of the nodes they keep, so an unchanged tree compares equal
  // and the derived structural equality answers the same question the rendered
  // comparison did — without building two copies of the whole stylesheet.
  let did_flatten = applied_ast != flattened_ast
  let did_rewrite = did_apply ||
    did_custom_utility ||
    did_custom_variant ||
    did_functions ||
    did_sources ||
    did_at_variant ||
    did_flatten
  let stylesheet = flattened_ast
  let has_utilities = contains_tailwind_utilities(stylesheet) || did_rewrite
  // `input` is read at exactly one place: `build`'s `!has_utilities` early
  // return, where the compiler echoes the stylesheet back because it generates
  // nothing of its own. Rendering it for a stylesheet that *does* have
  // `@tailwind utilities` — every real workload — is pure waste, and
  // `did_rewrite` implies `has_utilities`, so the rewrite case never needs it
  // either. Render only when the echo can actually happen.
  let input = if has_utilities {
    ""
  } else if had_imports {
    render_css_nodes(stylesheet)
  } else {
    source_css
  }
  let initial_candidates : Map[String, Unit] = Map([])
  for candidate in source_directives.included {
    if !source_directives.excluded.contains(candidate) {
      initial_candidates[candidate] = ()
    }
  }
  {
    input,
    polyfills: options.polyfills,
    stylesheet,
    theme,
    sources: source_directives.sources,
    candidates: initial_candidates,
    excluded_candidates: source_directives.excluded,
    custom_utilities,
    functional_utilities,
    custom_variants,
    has_utilities,
  }
}

///|
/// Reject the directives that only make sense with a JavaScript module loader.
///
/// JavaScript configuration files and plugins are out of scope, so they are
/// reported rather than silently ignored.
fn reject_javascript_directives(
  nodes : ArrayView[CssNode],
) -> Unit raise CompileError {
  for node in nodes {
    match node {
      AtRule(name="@plugin" | "@config", params~, ..) =>
        raise UnsupportedJsCompatibility(
          "JavaScript configuration and plugins are not supported: \{trim(params)}",
        )
      Rule(nodes~, ..) | AtRule(nodes=Some(nodes), ..) | Context(nodes~, ..) =>
        reject_javascript_directives(nodes)
      _ => ()
    }
  }
}

///|
fn contains_tailwind_utilities(nodes : ArrayView[CssNode]) -> Bool {
  for node in nodes {
    match node {
      AtRule(name="@tailwind", params~, ..) =>
        if params == "utilities" || params.has_prefix("utilities ") {
          return true
        }
      Rule(nodes~, ..) | AtRule(nodes=Some(nodes), ..) | Context(nodes~, ..) =>
        if contains_tailwind_utilities(nodes) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
/// Replace `@theme` and `@tailwind utilities` with their generated content.
///
/// Only the first of each is substituted, matching upstream: later `@theme`
/// blocks and repeated `@tailwind utilities` directives are dropped.
fn compose_stylesheet(
  nodes : ArrayView[CssNode],
  theme_rule : Array[CssNode],
  utilities : Array[CssNode],
  state : ComposeState,
) -> Array[CssNode] {
  let output : Array[CssNode] = []
  for node in nodes {
    match node {
      AtRule(name="@theme", ..) =>
        if !state.emitted_theme {
          state.emitted_theme = true
          for child in theme_rule {
            output.push(child)
          }
        }
      AtRule(name="@tailwind", params~, ..) =>
        if params == "utilities" || params.has_prefix("utilities ") {
          if !state.emitted_utilities {
            state.emitted_utilities = true
            for child in utilities {
              output.push(child)
            }
          }
        } else {
          output.push(node)
        }
      Rule(selector~, nodes=children, span~) =>
        output.push(
          Rule(
            selector~,
            nodes=compose_stylesheet(children, theme_rule, utilities, state),
            span~,
          ),
        )
      AtRule(name~, params~, nodes=Some(children), span~) => {
        let inner = compose_stylesheet(children, theme_rule, utilities, state)
        if !inner.is_empty() {
          output.push(AtRule(name~, params~, nodes=Some(inner), span~))
        }
      }
      Context(nodes=children, ..) =>
        for child in compose_stylesheet(children, theme_rule, utilities, state) {
          output.push(child)
        }
      _ => output.push(node)
    }
  }
  output
}

///|
priv struct ComposeState {
  mut emitted_theme : Bool
  mut emitted_utilities : Bool
}

///|
/// Return sources discovered while compiling the stylesheet.
pub fn Compiler::sources(self : Compiler) -> Array[Source] {
  self.sources.copy()
}

///|
/// Build CSS for all candidates seen so far.
///
/// Unknown candidates are ignored, as in the reference compiler.
pub fn Compiler::build(
  self : Compiler,
  candidates : ArrayView[String],
) -> String {
  for candidate in candidates {
    if !self.excluded_candidates.contains(candidate) {
      self.candidates[candidate] = ()
    }
  }
  if !self.has_utilities {
    return self.input
  }
  let rendered : Array[RenderedCandidate] = []
  for candidate, _ in self.candidates {
    match
      render_candidate(
        self.theme,
        self.custom_utilities,
        self.functional_utilities,
        self.custom_variants,
        candidate,
      ) {
      Some(css) => rendered.push(css)
      None => ()
    }
  }
  rendered.sort_by(compare_rendered_candidates)
  let generated_nodes : Array[CssNode] = []
  let generated_footer : Array[CssNode] = []
  for item in rendered {
    for node in flatten_css_nesting(item.nodes) {
      match node {
        AtRoot(..) =>
          if !generated_footer.contains(node) {
            generated_footer.push(node)
          }
        _ => generated_nodes.push(node)
      }
    }
  }
  generated_nodes.append(generated_footer)
  let base = render_css_nodes(remove_theme_nodes_deep(self.stylesheet))
  let generated = render_css_nodes(merge_adjacent_at_rules(generated_nodes))
  let usage = "\{base}\n\{generated}"
  // `@apply` can put generated custom properties in the base stylesheet too.
  let (property_header, property_footer) = render_generated_properties(
    usage,
    at_property_fallback=(self.polyfills & POLYFILL_AT_PROPERTY) != 0,
  )
  let composed_nodes = compose_stylesheet(
    self.stylesheet,
    theme_rule_nodes(self.theme, usage),
    generated_nodes,
    { emitted_theme: false, emitted_utilities: false },
  )
  let composed = merge_adjacent_at_rules(
    if (self.polyfills & POLYFILL_COLOR_MIX) != 0 {
      add_color_mix_fallback(composed_nodes, self.theme, false)
    } else {
      strip_color_mix_fallback(composed_nodes)
    },
  )
  let out = StringBuilder()
  out.write_string(property_header)
  out.write_string(render_css_nodes(composed))
  out.write_string(property_footer)
  out.write_string(render_used_keyframes(self.theme, generated))
  out.to_string()
}
