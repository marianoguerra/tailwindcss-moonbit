///|
/// `compile_css` is the JS/Wasm entry point for the Tailwind compiler.
///
/// - `css`: the input stylesheet source. Because this runs fully in memory with
///   no filesystem access, `@import` of external stylesheets is only resolved
///   when the files are supplied through `compile_css_json`'s `imports` map;
///   this simpler entry point compiles inline input only, e.g.
///   `@theme { --color-red-500: oklch(...); } @tailwind utilities;`.
/// - `candidates`: a newline-separated list of utility class names to generate.
///
/// Returns the generated CSS. If compilation fails, the returned string is a CSS
/// comment describing the error rather than a thrown exception, so the JS/Wasm
/// host always gets a string back.
pub fn compile_css(css : String, candidates : String) -> String {
  let cands = candidates
    .split("\n")
    .map(fn(line) { line.trim().to_owned() })
    .filter(fn(line) { line != "" })
    .collect()
  let compiler = @tw.compile_sync(css) catch {
    err => return "/* tailwindcss compile error: " + err.to_string() + " */"
  }
  compiler.build(cands)
}

///|
/// Structured JS/Wasm entry point supporting in-memory `@import` resolution,
/// polyfill selection, and structured error reporting.
///
/// `request` is a JSON string:
///
/// ```json
/// {
///   "css": "@import \"base.css\"; @tailwind utilities;",
///   "candidates": ["flex", "hover:bg-black"],
///   "imports": { "base.css": "@theme { --color-black: #000; }" },
///   "base": "",
///   "from": "input.css",
///   "polyfills": 3
/// }
/// ```
///
/// `imports` is an in-memory map of path → stylesheet content; there is no host
/// filesystem access, so any `@import` must be satisfied from this map. Every
/// field except `css` is optional (candidates default to none, polyfills to
/// `POLYFILL_ALL`).
///
/// Runs fully synchronously, so it is available on every backend including
/// wasm-gc.
///
/// Returns a JSON result string so the host never has to guess whether the
/// output is CSS or an error:
///
/// ```json
/// { "ok": true,  "css": "..." }
/// { "ok": false, "error": "InvalidCss(...)" }
/// ```
pub fn compile_css_json(request : String) -> String {
  let parsed = @json.parse(request) catch {
    err => return error_result("invalid request JSON: " + err.to_string())
  }
  let css = json_string(json_field(parsed, "css")).unwrap_or("")
  let candidates : Array[String] = []
  match json_field(parsed, "candidates") {
    Some(Array(items)) =>
      for item in items {
        match item {
          String(name) => {
            let trimmed = name.trim().to_owned()
            if trimmed != "" {
              candidates.push(trimmed)
            }
          }
          _ => ()
        }
      }
    _ => ()
  }
  let base = json_string(json_field(parsed, "base")).unwrap_or("")
  let from = json_string(json_field(parsed, "from"))
  let polyfills = match json_field(parsed, "polyfills") {
    Some(Number(value, ..)) => value.to_int()
    _ => @tw.POLYFILL_ALL
  }
  let loader = @tw.MemoryStylesheetLoader::new()
  match json_field(parsed, "imports") {
    Some(Object(files)) =>
      for path, content in files {
        match content {
          String(text) => loader.add(path, text)
          _ => ()
        }
      }
    _ => ()
  }
  let compiler = @tw.compile_sync(
    css,
    options=@tw.CompileOptions::new(
      base~,
      from?,
      sync_loader=loader,
      polyfills~,
    ),
  ) catch {
    err => return error_result(err.to_string())
  }
  success_result(compiler.build(candidates))
}

///|
/// Read a top-level field from a JSON object, or `None` if absent / not an object.
fn json_field(node : Json, key : String) -> Json? {
  match node {
    Object(fields) => fields.get(key)
    _ => None
  }
}

///|
/// Extract a string from an optional JSON node.
fn json_string(node : Json?) -> String? {
  match node {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn success_result(css : String) -> String {
  Json::object(Map([("ok", Json::boolean(true)), ("css", Json::string(css))])).stringify()
}

///|
fn error_result(message : String) -> String {
  Json::object(
    Map([("ok", Json::boolean(false)), ("error", Json::string(message))]),
  ).stringify()
}
