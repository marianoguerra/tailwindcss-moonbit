///|
/// The compiler version this module links, mirroring `../../moon.mod`.
const COMPILER_VERSION : String = "0.3.0"

///|
/// The `moonbit-community/html` version, mirroring `../moon.mod`.
const HTML_VERSION : String = "0.1.2"

///|
/// Compile an HTML fragment straight to CSS: scan it for `class` tokens, then
/// build a stylesheet containing only the rules those classes need.
///
/// This is the self-contained entry point — every call re-reads `imports`, so a
/// host that compiles repeatedly should use `bundle_load` + `compile_html`
/// instead and pay that cost once per session.
///
/// `request` is a JSON string:
///
/// ```json
/// {
///   "html": "<div class=\"btn btn-primary\">Go</div>",
///   "css": "@import \"tailwindcss\";",
///   "imports": { "tailwindcss": "@theme { ... } @tailwind utilities;" },
///   "base": "",
///   "from": "entry.css",
///   "polyfills": 3,
///   "extra_candidates": ["hidden"]
/// }
/// ```
///
/// Only `html` and `css` matter; everything else is optional. `imports` is an
/// in-memory map of path → stylesheet content, because there is no host
/// filesystem here — the CLI's `bundle` mode produces one from a project.
/// `extra_candidates` are added to whatever the scan found, for classes the host
/// knows about but that do not appear in the HTML.
///
/// The reply reports what was scanned and how long each stage took, measured
/// inside MoonBit rather than by the host:
///
/// ```json
/// { "ok": true, "css": "...", "candidates": ["btn"],
///   "counts": { "elements": 1, "classAttrs": 1, "candidates": 1,
///               "cssChars": 812, "imports": 1, "importChars": 30154 },
///   "timings": { "scanUs": 41.0, "compileUs": 17100.0,
///                "buildUs": 5900.0, "totalUs": 23041.0 } }
/// { "ok": false, "error": "StylesheetNotFound" }
/// ```
pub fn compile_html_json(request : String) -> String {
  let parsed = @json.parse(request) catch {
    err => return error_result("invalid request JSON: " + err.to_string())
  }
  compile_with_bundle(
    parse_bundle(parsed),
    json_string(json_field(parsed, "html")).unwrap_or(""),
    json_strings(json_field(parsed, "extra_candidates")),
  )
}

///|
/// Scan an HTML fragment for `class` tokens without compiling anything.
///
/// Microseconds where a compile is milliseconds, so a host can check whether the
/// candidate set actually changed before paying for a rebuild.
///
/// ```json
/// { "ok": true, "candidates": ["btn"],
///   "counts": { "elements": 1, "classAttrs": 1, "candidates": 1 },
///   "timings": { "scanUs": 41.0 } }
/// ```
pub fn scan_html_json(html : String) -> String {
  let started = @clock.monotonic_clock_start()
  let scan = scan_html(html)
  let scan_us = @clock.monotonic_clock_end(started)
  Json::object(
    Map([
      ("ok", Json::boolean(true)),
      ("candidates", candidates_json(scan.candidates)),
      ("counts", scan_counts_json(scan)),
      ("timings", Json::object(Map([("scanUs", Json::number(scan_us))]))),
    ]),
  ).stringify()
}

///|
/// Versions this module was built from, for a host to display.
///
/// The backend is deliberately absent: the host knows which artifact it loaded,
/// and reporting it from here would need a per-target source file.
pub fn build_info() -> String {
  Json::object(
    Map([
      ("compiler", Json::string(COMPILER_VERSION)),
      ("html", Json::string(HTML_VERSION)),
      ("polyfillsDefault", json_count(@tw.POLYFILL_ALL)),
    ]),
  ).stringify()
}

///|
/// Assemble the success reply of a compile.
///
/// Timings are captured before this runs, so serialising the stylesheet is never
/// counted as compile time. `compile_us` is `None` for a warm build, where no
/// import graph was parsed.
fn compile_result(
  css~ : String,
  scan~ : Scan,
  scan_us~ : Double,
  compile_us~ : Double?,
  build_us~ : Double,
  total_us~ : Double,
  bundle~ : Bundle,
) -> String {
  let timings = Map([
    ("scanUs", Json::number(scan_us)),
    ("buildUs", Json::number(build_us)),
    ("totalUs", Json::number(total_us)),
  ])
  match compile_us {
    Some(value) => timings["compileUs"] = Json::number(value)
    None => ()
  }
  let counts = scan_counts_map(scan)
  // `cssChars` counts UTF-16 code units, not bytes; a host that wants bytes
  // should encode the string itself.
  counts["cssChars"] = json_count(css.length())
  counts["imports"] = json_count(bundle.import_count)
  counts["importChars"] = json_count(bundle.import_chars)
  Json::object(
    Map([
      ("ok", Json::boolean(true)),
      ("css", Json::string(css)),
      ("candidates", candidates_json(scan.candidates)),
      ("counts", Json::object(counts)),
      ("timings", Json::object(timings)),
    ]),
  ).stringify()
}

///|
fn scan_counts_map(scan : Scan) -> Map[String, Json] {
  Map([
    ("elements", json_count(scan.elements)),
    ("classAttrs", json_count(scan.class_attrs)),
    ("candidates", json_count(scan.candidates.length())),
  ])
}

///|
fn scan_counts_json(scan : Scan) -> Json {
  Json::object(scan_counts_map(scan))
}
