// Implementations of the `declare`d component exports in `top.mbt`.
// Both simply delegate to the existing, already-tested `ffi` package of the
// `marianoguerra/tailwindcss` module (reused verbatim, see ffi/lib.mbt).

///|
pub fn compile_css_json(request : String) -> String {
  @ffi.compile_css_json(request)
}

///|
pub fn compile_css(css : String, candidates : String) -> String {
  @ffi.compile_css(css, candidates)
}
