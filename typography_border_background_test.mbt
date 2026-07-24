///|
async test "typography border background and overloaded color utilities" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme {
      #|  --spacing: 0.25rem;
      #|  --color-brand: oklch(60% .2 20);
      #|  --font-sans: Inter, sans-serif;
      #|  --text-sm: 0.875rem;
      #|  --text-sm--line-height: 1.25rem;
      #|  --radius-card: 0.75rem;
      #|  --border-width-wide: 3px;
      #|  --background-image-hero: url(hero.png);
      #|  --stroke-width-bold: 3;
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build([
    "font-sans", "text-sm/6", "tracking-[.1em]", "ordinal", "border-wide", "border-x-2",
    "border-dashed", "border-s-brand", "rounded-ss-card", "outline-hidden", "outline-brand/50",
    "bg-fixed", "bg-clip-text", "bg-[position:10%_20%]", "bg-cover", "bg-no-repeat",
    "bg-hero", "bg-brand/50", "stroke-bold", "stroke-brand", "decoration-brand",
  ])
  assert_true(output.contains("font-family: var(--font-sans)"))
  assert_true(output.contains("line-height: calc(var(--spacing) * 6)"))
  assert_true(output.contains("@property --tw-border-style"))
  assert_true(output.contains("border-inline-width: 2px"))
  assert_true(output.contains("border-start-start-radius: var(--radius-card)"))
  assert_true(output.contains("@media (forced-colors: active)"))
  assert_true(output.contains("background-position: 10% 20%"))
  assert_true(output.contains("background-image: var(--background-image-hero)"))
  assert_true(
    output.contains(
      "background-color: color-mix(in oklab, var(--color-brand) 50%, transparent)",
    ),
  )
  assert_true(output.contains("stroke-width: var(--stroke-width-bold)"))
  assert_true(output.contains("text-decoration-color: var(--color-brand)"))
}
