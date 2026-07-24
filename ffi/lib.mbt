///|
/// `compile_css` is the JS/Wasm entry point for the Tailwind compiler.
///
/// - `css`: the input stylesheet source. Because this runs fully in memory with
///   no filesystem access, `@import` of external stylesheets cannot be resolved
///   here. Provide inline input instead, e.g.
///   `@theme { --color-red-500: oklch(...); } @tailwind utilities;`.
/// - `candidates`: a newline-separated list of utility class names to generate.
///
/// Returns the generated CSS. If compilation fails (for example, an `@import`
/// that would need a loader), the returned string is a CSS comment describing
/// the error rather than a thrown exception, so the JS/Wasm host always gets a
/// string back.
pub fn compile_css(css : String, candidates : String) -> String {
  let cands = candidates
    .split("\n")
    .map(fn(line) { line.trim().to_owned() })
    .filter(fn(line) { line != "" })
    .collect()
  let mut result = ""
  @async.run_async_main(() => {
    let compiler = @tw.compile(css) catch {
      err => {
        result = "/* tailwindcss compile error: " + err.to_string() + " */"
        return
      }
    }
    result = compiler.build(cands)
  })
  result
}
