///|
/// Walk the `@import`/`@reference` graph of `css` and collect every transitively
/// imported stylesheet as a `path -> content` map.
///
/// The keys are the exact lexical paths `MemoryStylesheetLoader` uses for lookup
/// (`resolve_path(base, id)`), with the key chain seeded at `""`. The map is
/// therefore directly usable as the `imports` field of a compile request (e.g.
/// `compile_css_json` / the JS `compile({ input, imports })` wrapper) whenever the
/// entry `css` is compiled with the default `base = ""` — resolution replays the
/// same paths and finds every file.
///
/// Content is read through `loader`. `base~` is only the entry's on-disk resolution
/// base (the directory of the entry file) used for filesystem reads; it does not
/// affect the emitted keys. This lets a real filesystem loader resolve against actual
/// directories no matter where the entry lives, while the keys stay portable
/// (entry-relative, no absolute prefixes).
pub async fn collect_imports(
  css : String,
  loader : &StylesheetLoader,
  base~ : String = "",
) -> Map[String, String] raise CompileError {
  let files : Map[String, String] = Map([])
  collect_imports_from(parse_css(css), loader, "", base, [], files)
  files
}

///|
/// Recursive worker for `collect_imports`.
///
/// Mirrors the loading behaviour of `resolve_imports` but accumulates source files
/// instead of building an AST. Two bases advance in lockstep, both driven by the
/// same `spec.id` sequence:
///
/// - `key_base` — lexical, seeds the map keys (`resolve_path(key_base, id)`).
/// - `fs_base` — passed to `loader.load` so the loader resolves real files.
async fn collect_imports_from(
  nodes : ArrayView[CssNode],
  loader : &StylesheetLoader,
  key_base : String,
  fs_base : String,
  stack : Array[String],
  files : Map[String, String],
) -> Unit raise CompileError {
  for node in nodes {
    match node {
      AtRule(name~, params~, nodes=None, ..) =>
        if is_import_at_rule(name) {
          match parse_import_spec(params) {
            None => ()
            Some(spec) => {
              let key = resolve_path(key_base, spec.id)
              if stack.contains(key) {
                let cycle = stack.copy()
                cycle.push(key)
                raise ImportCycle(cycle)
              }
              // Already collected (diamond import): its subtree is covered too.
              if files.contains(key) {
                continue
              }
              let loaded = loader.load(spec.id, fs_base)
              files[key] = loaded.content
              let next_stack = stack.copy()
              next_stack.push(key)
              collect_imports_from(
                parse_css(loaded.content),
                loader,
                dirname(key),
                loaded.base,
                next_stack,
                files,
              )
            }
          }
        }
      Rule(nodes~, ..) | AtRule(nodes=Some(nodes), ..) =>
        collect_imports_from(nodes, loader, key_base, fs_base, stack, files)
      _ => ()
    }
  }
}
