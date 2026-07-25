///|
/// A self-contained entry so the tests need no generated assets.
const TEST_CSS : String = "@theme { --spacing: 0.25rem; } @tailwind utilities;\n"

///|
/// A two-file graph, to prove `imports` resolution and the counts reported for it.
fn test_request(html~ : String, extra? : Array[String] = []) -> String {
  Json::object(
    Map([
      ("html", Json::string(html)),
      ("css", Json::string("@import \"./theme.css\";\n@tailwind utilities;\n")),
      (
        "imports",
        Json::object(
          Map([("./theme.css", Json::string("@theme { --spacing: 0.25rem; }"))]),
        ),
      ),
      ("extra_candidates", Json::array(extra.map(Json::string))),
    ]),
  ).stringify()
}

///|
fn field(json : String, key : String) -> Json? {
  json_field(@json.parse(json), key) catch {
    _ => None
  }
}

///|
fn ok(json : String) -> Bool {
  field(json, "ok") is Some(True)
}

///|
test "compile_html_json: end to end" {
  let reply = compile_html_json(
    test_request(
      html="<div class=\"flex gap-2\"><i class=\"hidden\"></i></div>",
    ),
  )
  assert_true(ok(reply))
  let parsed = @json.parse(reply)
  debug_inspect(
    json_field(parsed, "candidates"),
    content=(
      #|Some(Array([String("flex"), String("gap-2"), String("hidden")]))
    ),
  )
  guard json_field(parsed, "css") is Some(String(css))
  assert_true(css.contains("display: flex"))
  assert_true(css.contains("gap: calc(var(--spacing) * 2)"))
  // The theme variable the utility references came from the imported file.
  assert_true(css.contains("--spacing: 0.25rem"))
  // hidden is a real utility, so all three candidates produced rules.
  assert_true(css.contains("display: none"))
  guard json_field(parsed, "counts") is Some(counts)
  debug_inspect(
    json_field(counts, "imports"),
    content=(
      #|Some(Number(1))
    ),
  )
  debug_inspect(
    json_field(counts, "importChars"),
    content=(
      #|Some(Number(30))
    ),
  )
  debug_inspect(
    json_field(counts, "candidates"),
    content=(
      #|Some(Number(3))
    ),
  )
  guard json_field(counts, "cssChars") is Some(Number(chars, ..))
  assert_eq(chars.to_int(), css.length())
}

///|
test "compile_html_json: extra candidates join the scanned ones" {
  let reply = compile_html_json(
    test_request(html="<div class=\"flex\">", extra=["block", "  ", "grid"]),
  )
  debug_inspect(
    json_field(@json.parse(reply), "candidates"),
    content=(
      #|Some(Array([String("flex"), String("block"), String("grid")]))
    ),
  )
}

///|
test "compile_html_json: timings cover every stage" {
  let reply = compile_html_json(test_request(html="<div class=\"flex\">"))
  guard json_field(@json.parse(reply), "timings") is Some(timings)
  for key in ["scanUs", "compileUs", "buildUs", "totalUs"] {
    guard json_field(timings, key) is Some(Number(value, ..)) else {
      fail("missing timing " + key)
    }
    assert_true(value >= 0.0)
  }
}

///|
test "compile_html_json: failures come back as ok:false" {
  let missing = compile_html_json(
    Json::object(
      Map([
        ("html", Json::string("<div class=\"flex\">")),
        ("css", Json::string("@import \"nope.css\";")),
      ]),
    ).stringify(),
  )
  assert_false(ok(missing))
  debug_inspect(
    field(missing, "error"),
    content=(
      #|Some(String("StylesheetNotFound(nope.css)"))
    ),
  )
  let malformed = compile_html_json("{not json")
  assert_false(ok(malformed))
  assert_true(
    field(malformed, "error") is Some(String(text)) &&
    text.contains("invalid request JSON"),
  )
}

///|
test "scan_html_json: candidates and counts without compiling" {
  let reply = scan_html_json(
    "<tr class=\"hover\"><td class=\"p-2 p-2\">x</td></tr>",
  )
  assert_true(ok(reply))
  debug_inspect(
    field(reply, "candidates"),
    content=(
      #|Some(Array([String("hover"), String("p-2")]))
    ),
  )
  debug_inspect(
    field(reply, "counts"),
    content=(
      #|Some(
      #|  Object(
      #|    {
      #|      "elements": Number(2),
      #|      "classAttrs": Number(2),
      #|      "candidates": Number(2),
      #|    },
      #|  ),
      #|)
    ),
  )
  guard field(reply, "timings") is Some(timings)
  assert_true(json_field(timings, "scanUs") is Some(Number(_)))
  // Scanning never compiles, so there is nothing else to report.
  assert_true(json_field(timings, "compileUs") is None)
}

///|
test "build_info: reports the linked versions" {
  debug_inspect(
    build_info(),
    content=(
      #|"{\"compiler\":\"0.2.0\",\"html\":\"0.1.2\",\"polyfillsDefault\":3}"
    ),
  )
}

///|
test "bundle handles: load once, compile many" {
  let loaded = bundle_load(
    Json::object(
      Map([("css", Json::string(TEST_CSS)), ("imports", Json::object(Map([])))]),
    ).stringify(),
  )
  assert_true(ok(loaded))
  debug_inspect(
    field(loaded, "counts"),
    content=(
      #|Some(
      #|  Object(
      #|    {
      #|      "imports": Number(0),
      #|      "importChars": Number(0),
      #|      "cssChars": Number(52),
      #|    },
      #|  ),
      #|)
    ),
  )
  guard field(loaded, "bundle") is Some(Number(handle, ..))
  let bundle = handle.to_int()

  // A fresh compiler per call, so the output tracks the input in both directions.
  let first = compile_html(bundle, "<div class=\"flex gap-2\">")
  assert_true(ok(first))
  guard field(first, "css") is Some(String(wide))
  assert_true(wide.contains("display: flex") && wide.contains("gap: calc"))
  let second = compile_html(bundle, "<div class=\"flex\">")
  guard field(second, "css") is Some(String(narrow))
  assert_true(narrow.contains("display: flex"))
  assert_false(narrow.contains("gap: calc")) // shrank when the class went away
  bundle_free(bundle)
  assert_false(ok(compile_html(bundle, "<div class=\"flex\">")))
  debug_inspect(
    field(compile_html(bundle, ""), "error"),
    content=(
      #|Some(String("unknown bundle handle: 1"))
    ),
  )
}

///|
/// The warm path is faster but additive: `Compiler::build` accumulates
/// candidates, so deleting a class does not remove its rules. That asymmetry is
/// the whole reason `compile_html` exists, so pin it down here.
test "warm compiler: no graph parse, and output only grows" {
  let loaded = bundle_load(
    Json::object(Map([("css", Json::string(TEST_CSS))])).stringify(),
  )
  guard field(loaded, "bundle") is Some(Number(handle, ..))
  let bundle = handle.to_int()
  let opened = compiler_open(bundle)
  assert_true(ok(opened))
  guard field(opened, "timings") is Some(timings)
  assert_true(json_field(timings, "compileUs") is Some(Number(_)))
  guard field(opened, "compiler") is Some(Number(compiler_handle, ..))
  let compiler = compiler_handle.to_int()
  let first = compiler_build_html(compiler, "<div class=\"flex gap-2\">")
  assert_true(ok(first))
  guard field(first, "timings") is Some(warm_timings)
  // No import graph was parsed on this call, so there is no compile stage.
  assert_true(json_field(warm_timings, "compileUs") is None)
  assert_true(json_field(warm_timings, "buildUs") is Some(Number(_)))
  let second = compiler_build_html(compiler, "<div class=\"flex\">")
  guard field(second, "css") is Some(String(css))
  assert_true(css.contains("display: flex"))
  assert_true(css.contains("gap: calc")) // still there: candidates accumulate
  compiler_close(compiler)
  assert_false(ok(compiler_build_html(compiler, "<div class=\"flex\">")))
  bundle_free(bundle)
}

///|
test "bundle_free: drops the warm compilers opened from it" {
  let loaded = bundle_load(
    Json::object(Map([("css", Json::string(TEST_CSS))])).stringify(),
  )
  guard field(loaded, "bundle") is Some(Number(handle, ..))
  let bundle = handle.to_int()
  guard field(compiler_open(bundle), "compiler") is Some(Number(warm, ..))
  bundle_free(bundle)
  assert_false(ok(compiler_build_html(warm.to_int(), "<div class=\"flex\">")))
}

///|
test "bundle handles: unknown handles are reported, not crashed on" {
  debug_inspect(
    field(compile_html(9999, "<div class=\"flex\">"), "error"),
    content=(
      #|Some(String("unknown bundle handle: 9999"))
    ),
  )
  debug_inspect(
    field(compiler_open(9999), "error"),
    content=(
      #|Some(String("unknown bundle handle: 9999"))
    ),
  )
  debug_inspect(
    field(compiler_build_html(9999, ""), "error"),
    content=(
      #|Some(String("unknown compiler handle: 9999"))
    ),
  )
  // Freeing an unknown handle is a no-op rather than an error.
  bundle_free(9999)
  compiler_close(9999)
}
