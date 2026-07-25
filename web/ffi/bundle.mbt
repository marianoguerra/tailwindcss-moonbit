///|
/// A parsed compile request minus the HTML: the entry stylesheet plus the
/// in-memory files its `@import`s resolve against.
///
/// Parsing this is the expensive part of a request — margaui's graph is ~270 KB
/// across 80-odd files — so hosts that compile repeatedly load it once through
/// `bundle_load` and then pass the handle back per keystroke.
priv struct Bundle {
  css : String
  loader : @tw.MemoryStylesheetLoader
  base : String
  from : String?
  polyfills : Int
  import_count : Int
  import_chars : Int
}

///|
/// A `Bundle` plus a live `Compiler`, for the incremental mode.
priv struct Warm {
  bundle_handle : Int
  bundle : Bundle
  compiler : @tw.Compiler
}

///|
/// Handles live in these tables rather than crossing the boundary as pointers,
/// so the contract is identical on wasm-gc and on the js fallback.
let bundles : Map[Int, Bundle] = Map([])

///|
let warm_compilers : Map[Int, Warm] = Map([])

///|
let next_handle : Ref[Int] = Ref(1)

///|
fn take_handle() -> Int {
  let handle = next_handle.val
  next_handle.val = handle + 1
  handle
}

///|
/// Read `{css, imports, base?, from?, polyfills?}` out of a request.
///
/// Missing fields are tolerated: an absent `imports` just means the entry has to
/// be self-contained, and `polyfills` defaults to `POLYFILL_ALL` as everywhere
/// else in this compiler.
fn parse_bundle(request : Json) -> Bundle {
  let loader = @tw.MemoryStylesheetLoader::new()
  let mut import_count = 0
  let mut import_chars = 0
  match json_field(request, "imports") {
    Some(Object(files)) =>
      for path, content in files {
        match content {
          String(text) => {
            loader.add(path, text)
            import_count += 1
            import_chars += text.length()
          }
          _ => ()
        }
      }
    _ => ()
  }
  {
    css: json_string(json_field(request, "css")).unwrap_or(""),
    loader,
    base: json_string(json_field(request, "base")).unwrap_or(""),
    from: json_string(json_field(request, "from")),
    polyfills: match json_field(request, "polyfills") {
      Some(Number(value, ..)) => value.to_int()
      _ => @tw.POLYFILL_ALL
    },
    import_count,
    import_chars,
  }
}

///|
fn Bundle::options(self : Bundle) -> @tw.CompileOptions {
  @tw.CompileOptions::new(
    base=self.base,
    from?=self.from,
    sync_loader=self.loader,
    polyfills=self.polyfills,
  )
}

///|
/// Parse a bundle once and keep it, returning a handle to compile against.
///
/// `bundle_json` is `{css, imports, base?, from?, polyfills?}` — exactly what the
/// CLI's `bundle` mode emits, wrapped with the entry stylesheet.
///
/// ```json
/// { "ok": true, "bundle": 1,
///   "counts": { "imports": 81, "importChars": 275750, "cssChars": 2480 } }
/// ```
pub fn bundle_load(bundle_json : String) -> String {
  let parsed = @json.parse(bundle_json) catch {
    err => return error_result("invalid bundle JSON: " + err.to_string())
  }
  let bundle = parse_bundle(parsed)
  let handle = take_handle()
  bundles[handle] = bundle
  Json::object(
    Map([
      ("ok", Json::boolean(true)),
      ("bundle", json_count(handle)),
      (
        "counts",
        Json::object(
          Map([
            ("imports", json_count(bundle.import_count)),
            ("importChars", json_count(bundle.import_chars)),
            ("cssChars", json_count(bundle.css.length())),
          ]),
        ),
      ),
    ]),
  ).stringify()
}

///|
/// Release a bundle handle. Any warm compilers opened from it are dropped too.
pub fn bundle_free(bundle : Int) -> Unit {
  bundles.remove(bundle)
  let stale : Array[Int] = []
  for handle, warm in warm_compilers {
    if warm.bundle_handle == bundle {
      stale.push(handle)
    }
  }
  for handle in stale {
    warm_compilers.remove(handle)
  }
}

///|
/// Compile an HTML fragment against a loaded bundle.
///
/// A *fresh* `Compiler` per call, which is the honest cost of a live editor: the
/// import graph is re-read every time, and the output therefore shrinks again
/// when classes are deleted. `compiler_open` trades that away for speed.
pub fn compile_html(bundle : Int, html : String) -> String {
  match bundles.get(bundle) {
    Some(loaded) => compile_with_bundle(loaded, html, [])
    None => error_result("unknown bundle handle: " + bundle.to_string())
  }
}

///|
/// Open a long-lived `Compiler` over a bundle, paying the import-graph parse once.
///
/// The caveat is inherent to `Compiler::build`: candidates accumulate across
/// calls, so the stylesheet only ever grows. Deleting a class from the HTML will
/// *not* remove its rules from subsequent output. Use `compile_html` when the
/// result has to track the input exactly.
///
/// ```json
/// { "ok": true, "compiler": 2, "timings": { "compileUs": 17100.0 } }
/// ```
pub fn compiler_open(bundle : Int) -> String {
  guard bundles.get(bundle) is Some(loaded) else {
    return error_result("unknown bundle handle: " + bundle.to_string())
  }
  let started = @clock.monotonic_clock_start()
  let compiler = @tw.compile_sync(loaded.css, options=loaded.options()) catch {
    err => return error_result(err.to_string())
  }
  let compile_us = @clock.monotonic_clock_end(started)
  let handle = take_handle()
  warm_compilers[handle] = { bundle_handle: bundle, bundle: loaded, compiler }
  Json::object(
    Map([
      ("ok", Json::boolean(true)),
      ("compiler", json_count(handle)),
      ("timings", Json::object(Map([("compileUs", Json::number(compile_us))]))),
    ]),
  ).stringify()
}

///|
/// Scan a fragment and build against an already-open compiler: no graph parse, so
/// `timings` has no `compileUs`.
pub fn compiler_build_html(compiler : Int, html : String) -> String {
  guard warm_compilers.get(compiler) is Some(warm) else {
    return error_result("unknown compiler handle: " + compiler.to_string())
  }
  let started = @clock.monotonic_clock_start()
  let scan = scan_html(html)
  let scan_us = @clock.monotonic_clock_end(started)
  let build_started = @clock.monotonic_clock_start()
  let generated = warm.compiler.build(scan.candidates)
  let build_us = @clock.monotonic_clock_end(build_started)
  compile_result(
    css=generated,
    scan~,
    scan_us~,
    compile_us=None,
    build_us~,
    total_us=@clock.monotonic_clock_end(started),
    bundle=warm.bundle,
  )
}

///|
/// Release a warm compiler handle.
pub fn compiler_close(compiler : Int) -> Unit {
  warm_compilers.remove(compiler)
}

///|
/// Scan, compile the graph, and build — the shared body of `compile_html` and
/// `compile_html_json`.
fn compile_with_bundle(
  bundle : Bundle,
  html : String,
  extra_candidates : Array[String],
) -> String {
  let started = @clock.monotonic_clock_start()
  let scan = scan_html(html)
  let scan_us = @clock.monotonic_clock_end(started)
  for extra in extra_candidates {
    scan.candidates.push(extra)
  }
  let compile_started = @clock.monotonic_clock_start()
  let compiler = @tw.compile_sync(bundle.css, options=bundle.options()) catch {
    err => return error_result(err.to_string())
  }
  let compile_us = @clock.monotonic_clock_end(compile_started)
  let build_started = @clock.monotonic_clock_start()
  let generated = compiler.build(scan.candidates)
  let build_us = @clock.monotonic_clock_end(build_started)
  compile_result(
    css=generated,
    scan~,
    scan_us~,
    compile_us=Some(compile_us),
    build_us~,
    total_us=@clock.monotonic_clock_end(started),
    bundle~,
  )
}
