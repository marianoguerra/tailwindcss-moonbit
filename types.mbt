///|
/// An error reported while parsing a Tailwind stylesheet.
pub(all) suberror CompileError {
  InvalidCss(String)
  MissingStylesheetLoader(String)
  StylesheetNotFound(String)
  ImportCycle(Array[String])
  UnsupportedJsCompatibility(String)
  InvalidApplyCandidate(String)
} derive(Eq, Debug)

///|
/// Human-readable rendering, used when reporting failures back to a host.
pub impl Show for CompileError with fn output(self, logger) {
  let message = match self {
    InvalidCss(detail) => "InvalidCss(\{detail})"
    MissingStylesheetLoader(detail) => "MissingStylesheetLoader(\{detail})"
    StylesheetNotFound(path) => "StylesheetNotFound(\{path})"
    ImportCycle(paths) => "ImportCycle(\{paths.join(" -> ")})"
    UnsupportedJsCompatibility(detail) =>
      "UnsupportedJsCompatibility(\{detail})"
    InvalidApplyCandidate(detail) => "InvalidApplyCandidate(\{detail})"
  }
  logger.write_string(message)
}

///|
/// A stylesheet returned by a `StylesheetLoader`.
pub(all) struct LoadedStylesheet {
  content : String
  path : String
  base : String
} derive(Eq, Debug)

///|
/// Asynchronous host interface used to resolve CSS `@import` directives.
///
/// Use this with `compile` when resolution needs real I/O (for example the
/// native filesystem loader). For hosts without an async runtime — notably the
/// wasm-gc backend — implement `SyncStylesheetLoader` and call `compile_sync`.
pub(open) trait StylesheetLoader {
  async fn load(Self, id : String, base : String) -> LoadedStylesheet raise CompileError
}

///|
/// Synchronous host interface used to resolve CSS `@import` directives.
///
/// This is the counterpart of `StylesheetLoader` for `compile_sync`. It suits
/// in-memory resolution (see `MemoryStylesheetLoader`, which implements both
/// traits) and any host that cannot drive an async runtime, such as wasm-gc.
pub(open) trait SyncStylesheetLoader {
  fn load(Self, id : String, base : String) -> LoadedStylesheet raise CompileError
}

///|
/// Emit no optional polyfill.
pub const POLYFILL_NONE : Int = 0

///|
/// Emit the `@layer properties` fallback for registered custom properties.
pub const POLYFILL_AT_PROPERTY : Int = 1

///|
/// Emit the `color-mix()` fallback guarded by `@supports`.
pub const POLYFILL_COLOR_MIX : Int = 2

///|
/// Emit every optional polyfill, which is the default.
pub const POLYFILL_ALL : Int = 3

///|
/// Options controlling stylesheet compilation.
pub struct CompileOptions {
  base : String
  from : String?
  loader : &StylesheetLoader?
  sync_loader : &SyncStylesheetLoader?
  polyfills : Int
}

///|
/// Construct compile options while preserving the defaults of `compile(css)`.
///
/// `loader` resolves `@import`s for the async `compile`; `sync_loader` does the
/// same for `compile_sync`. Supply whichever matches the entry point in use.
pub fn CompileOptions::new(
  base? : String = "",
  from? : String,
  loader? : &StylesheetLoader,
  sync_loader? : &SyncStylesheetLoader,
  polyfills? : Int = POLYFILL_ALL,
) -> CompileOptions {
  { base, from, loader, sync_loader, polyfills }
}

///|
/// A source pattern discovered in an `@source` directive.
pub(all) struct Source {
  base : String
  pattern : String
  negated : Bool
} derive(Eq, Debug, ToJson)

///|
/// The reusable result of parsing a Tailwind stylesheet.
///
/// Pass candidate class names to `build`. Candidates accumulate, matching the
/// incremental behavior of Tailwind CSS v4's JavaScript compiler.
pub struct Compiler {
  input : String
  polyfills : Int
  stylesheet : Array[CssNode]
  theme : Map[String, String]
  sources : Array[Source]
  candidates : Map[String, Unit]
  excluded_candidates : Map[String, Unit]
  custom_utilities : Map[String, Array[CssNode]]
  functional_utilities : Map[String, Array[CssNode]]
  custom_variants : Map[String, CustomVariantTemplate]
  has_utilities : Bool
}
