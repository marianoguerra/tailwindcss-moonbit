///|
async test "adjacent rules and at-rules are merged and declarations deduped" {
  let compiler = @tailwindcss.compile(
    (
      #|.a { color: red; color: blue; color: red }
      #|.b { color: red } .b { color: blue }
      #|@media print { .c { color: red } }
      #|@media print { .d { color: red } }
      #|@tailwind utilities;
      #|
    ),
  )
  inspect(
    compiler.build([]),
    content=(
      #|.a {
      #|  color: blue;
      #|  color: red;
      #|}
      #|.b {
      #|  color: red;
      #|  color: blue;
      #|}
      #|@media print {
      #|  .c {
      #|    color: red;
      #|  }
      #|  .d {
      #|    color: red;
      #|  }
      #|}
      #|
    ),
  )
}

///|
async test "polyfills can be disabled individually" {
  let css = "@theme { --color-brand: oklch(60% .2 20); }\n@tailwind utilities;"
  let candidates = ["border-2", "bg-brand/50"]
  let all = @tailwindcss.compile(css).build(candidates)
  assert_true(all.contains("@layer properties"))
  assert_true(all.contains("@supports (color: color-mix(in lab, red, red))"))
  let none = @tailwindcss.compile(
    css,
    options=@tailwindcss.CompileOptions::new(
      polyfills=@tailwindcss.POLYFILL_NONE,
    ),
  ).build(candidates)
  assert_true(!none.contains("@layer properties"))
  assert_true(!none.contains("@supports (color: color-mix(in lab, red, red))"))
  assert_true(none.contains("@property --tw-border-style"))
  assert_true(
    none.contains(
      "background-color: color-mix(in oklab, var(--color-brand) 50%, transparent)",
    ),
  )
  let at_property = @tailwindcss.compile(
    css,
    options=@tailwindcss.CompileOptions::new(
      polyfills=@tailwindcss.POLYFILL_AT_PROPERTY,
    ),
  ).build(candidates)
  assert_true(at_property.contains("@layer properties"))
  assert_true(
    !at_property.contains("@supports (color: color-mix(in lab, red, red))"),
  )
  let color_mix = @tailwindcss.compile(
    css,
    options=@tailwindcss.CompileOptions::new(
      polyfills=@tailwindcss.POLYFILL_COLOR_MIX,
    ),
  ).build(candidates)
  assert_true(!color_mix.contains("@layer properties"))
  assert_true(
    color_mix.contains("@supports (color: color-mix(in lab, red, red))"),
  )
}
