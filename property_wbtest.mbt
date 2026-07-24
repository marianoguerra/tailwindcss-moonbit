// Property and fuzz tests.
//
// These generate many inputs from a deterministic pseudo-random sequence and
// assert invariants that must hold for every input: parsers never panic, and
// rendering a parsed tree and parsing it again is stable.

///|
/// A small linear congruential generator, so the fuzz corpus is deterministic.
priv struct Rng {
  mut state : UInt64
}

///|
fn Rng::new(seed : UInt64) -> Rng {
  { state: seed }
}

///|
fn Rng::next(self : Rng) -> UInt64 {
  self.state = self.state * 6364136223846793005UL + 1442695040888963407UL
  self.state
}

///|
fn Rng::below(self : Rng, bound : Int) -> Int {
  (self.next() >> 33).to_int() % bound
}

///|
/// Build a random candidate-ish string from a small alphabet with structure.
fn random_candidate(rng : Rng) -> String {
  let pieces = [
    "hover:", "focus:", "sm:", "md:", "dark:", "group-hover:", "peer-focus:", "has-[a]:",
    "not-", "aria-checked:", "data-[x=y]:", "[&_p]:", "-", "!", "bg-red-500", "text-brand",
    "m-4", "p-[10px]", "flex", "w-1/2", "grid-cols-3", "space-x-4", "divide-y", "[color:red]",
    "translate-x-2", "border", "/50", "(--my-var)", "[", "]", "(", ")", "_", "/",
    "\\", "#", "@container",
  ]
  let out = StringBuilder()
  let count = rng.below(6) + 1
  for _ in 0..<count {
    out.write_string(pieces[rng.below(pieces.length())])
  }
  out.to_string()
}

///|
/// A random CSS value, biased towards functions and separators.
fn random_value(rng : Rng) -> String {
  let pieces = [
    "calc(", ")", "var(", "--x", ",", " ", "+", "-", "*", "/", "1px", "2rem", "100%",
    "red", "#abc", "[", "]", "'", "\"", "url(", "min(", "max(", "0",
  ]
  let out = StringBuilder()
  let count = rng.below(8) + 1
  for _ in 0..<count {
    out.write_string(pieces[rng.below(pieces.length())])
  }
  out.to_string()
}

///|
/// A random selector fragment.
fn random_selector(rng : Rng) -> String {
  let pieces = [
    "&", ".x", "#id", "[data-a]", ":hover", "::before", " ", ">", "+", "~", ",",
    "*", "a", "is(", ":is(", ")", "(", "[", "]", "\"", "'",
  ]
  let out = StringBuilder()
  let count = rng.below(8) + 1
  for _ in 0..<count {
    out.write_string(pieces[rng.below(pieces.length())])
  }
  out.to_string()
}

///|
test "candidate parsing never panics" {
  let rng = Rng::new(0x1234_5678_9abc_def0)
  for _ in 0..<3000 {
    let input = random_candidate(rng)
    // The result is intentionally ignored; the point is that parsing an
    // arbitrary string terminates without a panic.
    let _ = parse_candidate(input)
  }
}

///|
test "value parsing never panics on random input" {
  let rng = Rng::new(0x0fed_cba9_8765_4321)
  for _ in 0..<3000 {
    // Parsing and rendering arbitrary bytes must terminate without a panic,
    // even when brackets, quotes and functions are unbalanced.
    let _ = render_value(parse_value(random_value(rng)))
  }
}

///|
test "selector parsing never panics on random input" {
  let rng = Rng::new(0xabcd_1234_5678_ef90)
  for _ in 0..<3000 {
    let _ = render_selector(parse_selector(random_selector(rng)))
  }
}

///|
test "balanced value and selector inputs round-trip" {
  // Rendering a parse tree yields balanced output, so a second parse and
  // render must reach a fixed point.
  for
    input in [
      "calc(1px + 2px)", "var(--x, 1rem)", "rgb(1, 2, 3)", "min(10px, 5%)", "url(http://x/y)",
      "1px 2px 3px",
    ] {
    let once = render_value(parse_value(input))
    assert_eq(once, render_value(parse_value(once)))
  }
  for
    input in [
      "&:hover", ".a > .b", "&::before", ":is(.a, .b)", "[data-x='y']", "&:nth-child(2n of .item)",
      ".a .b .c",
    ] {
    let once = render_selector(parse_selector(input))
    assert_eq(once, render_selector(parse_selector(once)))
  }
}

///|
test "value rendering preserves the original bytes for simple inputs" {
  // Plain values without normalisation must survive a parse/render round-trip.
  for
    input in [
      "1px", "calc(1px + 2px)", "var(--x, 1rem)", "rgb(1, 2, 3)", "#abcdef", "min(10px, 5%)",
      "\"a string\"", "url(http://x/y.png)",
    ] {
    assert_eq(render_value(parse_value(input)), input)
  }
}

///|
test "css parsing round-trips rendered stylesheets" {
  let fixtures = [
    ".a { color: red }", "@media print { .b { color: blue } }", "@theme { --color-x: #123 }",
    ".c { .d { color: green } }", "/* license */ .e { color: red !important }", "@supports (display: grid) { .f { display: grid } }",
  ]
  for fixture in fixtures {
    let once = render_css_nodes(parse_css(fixture))
    let twice = render_css_nodes(parse_css(once))
    assert_eq(once, twice)
  }
}

///|
test "unbalanced selector parens do not panic" {
  // Found by the selector fuzzer: an unmatched `(` used to slice out of range.
  let _ = render_selector(parse_selector(":is(::before"))
  let _ = render_selector(parse_selector("&:where("))
  let _ = render_selector(parse_selector(".a:not("))
}
