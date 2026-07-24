///|
/// Portable in-process benchmark driver for the Tailwind compiler.
///
/// Compiled to native / js / wasm-gc and executed via `moon run --target <t>
/// benchmarks/bench -- <args>`. Timing uses `moonbitlang/core/bench`'s monotonic
/// clock (portable across all backends) and `moonbitlang/core/env`'s portable
/// argv, so one code path is measured with one clock on every target.
///
/// Argv protocol (after the `--` moon passes to the program). The request JSON is
/// passed as one or more chunks AFTER a `--req` marker and concatenated, because
/// Linux caps a single argv string at 128 KB (`MAX_ARG_STRLEN`) while the margaui
/// request is ~290 KB; chunking keeps each argument small while staying well under
/// the ~2 MB total `ARG_MAX`. Tokens BEFORE `--req` carry the mode/params and may
/// be preceded by a backend-supplied program name, so they are parsed positionally:
///
/// - Timed:  `[argv0] <warmup> <iters> --req <chunk>...`
///     Runs `warmup` discarded iterations, then `iters` timed iterations of a
///     FRESH `compile_sync()` + `build()` (fresh compiler each time — `build`
///     accumulates candidates, so reusing one would time growing work). Prints
///     one JSON line: {"ok":true,"samples_us":[...],"outLen":N}.
///
/// - Emit:   `[argv0] --emit --req <chunk>...`
///     Compiles once and prints ONLY the generated CSS (no timing). Used by the
///     orchestrator's correctness gate.
///
/// The request JSON mirrors `ffi/lib.mbt::compile_css_json`:
///   {css, candidates:[], imports:{path:content}, base, from, polyfills}
fn main {
  let raw = @env.args()
  // Split argv at the `--req` marker: everything after is request chunks.
  let mut marker = -1
  for i in 0..<raw.length() {
    if raw[i] == "--req" {
      marker = i
      break
    }
  }
  guard marker >= 0 else {
    println(
      "usage: bench <warmup> <iters> --req <chunk>... | bench --emit --req <chunk>...",
    )
    return
  }
  let request = StringBuilder::new()
  for i in (marker + 1)..<raw.length() {
    request.write_string(raw[i])
  }
  let req_json = request.to_string()
  // Interpret the pre-marker tokens positionally (a leading program name, if the
  // backend supplies one, is simply ignored — `--emit` and the trailing two
  // integers are located explicitly).
  let mut emit = false
  let ints : Array[Int] = []
  for i in 0..<marker {
    if raw[i] == "--emit" {
      emit = true
    } else {
      let parsed = try {
        Some(@string.parse_int(raw[i]))
      } catch {
        _ => None
      }
      match parsed {
        Some(n) => ints.push(n)
        None => ()
      }
    }
  }
  if emit {
    run_emit(req_json)
  } else {
    let warmup = if ints.length() >= 2 { ints[ints.length() - 2] } else { 5 }
    let iters = if ints.length() >= 1 { ints[ints.length() - 1] } else { 50 }
    run_timed(req_json, warmup, iters)
  }
}

///|
/// A parsed compile request plus a ready-to-use in-memory loader.
struct Request {
  css : String
  candidates : Array[String]
  loader : @tw.MemoryStylesheetLoader
  base : String
  from : String?
  polyfills : Int
}

///|
fn parse_request(request : String) -> Request raise {
  let parsed = @json.parse(request)
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
  { css, candidates, loader, base, from, polyfills }
}

///|
/// Compile the request once and return the generated CSS.
fn compile_once(req : Request) -> String raise {
  let compiler = @tw.compile_sync(
    req.css,
    options=@tw.CompileOptions::new(
      base=req.base,
      from?=req.from,
      sync_loader=req.loader,
      polyfills=req.polyfills,
    ),
  )
  compiler.build(req.candidates)
}

///|
fn run_emit(request : String) -> Unit {
  let out = try {
    let req = parse_request(request)
    compile_once(req)
  } catch {
    err => "/* bench compile error: " + err.to_string() + " */"
  }
  println(out)
}

///|
fn run_timed(request : String, warmup : Int, iters : Int) -> Unit {
  let req = try {
    parse_request(request)
  } catch {
    err => {
      println("{\"ok\":false,\"error\":" +
        Json::string(err.to_string()).stringify() + "}")
      return
    }
  }
  // A Bench instance is only used as a sink for `keep`, defeating dead-code
  // elimination of the compile result.
  let sink = @cbench.Bench()
  // Warmup — discarded.
  for _ in 0..<warmup {
    let out = try {
      compile_once(req)
    } catch {
      err => "/* " + err.to_string() + " */"
    }
    sink.keep(out)
  }
  // Timed — one sample (microseconds) per fresh compile+build.
  let samples : Array[Double] = []
  for _ in 0..<iters {
    let t = @cbench.monotonic_clock_start()
    let out = try {
      compile_once(req)
    } catch {
      err => "/* " + err.to_string() + " */"
    }
    let us = @cbench.monotonic_clock_end(t)
    sink.keep(out)
    samples.push(us)
  }
  let out_len = try { compile_once(req).length() } catch { _ => 0 }
  let parts = samples.map(fn(s) { s.to_string() })
  println(
    "{\"ok\":true,\"samples_us\":[" +
    parts.join(",") +
    "],\"outLen\":" +
    out_len.to_string() +
    "}",
  )
}

///|
fn json_field(node : Json, key : String) -> Json? {
  match node {
    Object(fields) => fields.get(key)
    _ => None
  }
}

///|
fn json_string(node : Json?) -> String? {
  match node {
    Some(String(value)) => Some(value)
    _ => None
  }
}
