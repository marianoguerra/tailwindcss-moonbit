///|
async test "space and divide utilities emit child selectors" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme {
      #|  --spacing: 0.25rem;
      #|  --color-brand: oklch(60% .2 20);
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build([
    "space-x-4", "space-y-2", "space-x-reverse", "space-y-reverse", "-space-x-4",
    "space-x-0", "space-x-px", "divide-x", "divide-y-4", "divide-x-reverse", "divide-y-reverse",
    "divide-dashed", "divide-brand", "divide-brand/50",
  ])
  assert_true(output.contains(":where(.space-x-4 > :not(:last-child))"))
  assert_true(
    output.contains(
      "margin-inline-start: calc(calc(var(--spacing) * 4) * var(--tw-space-x-reverse))",
    ),
  )
  assert_true(
    output.contains(
      "margin-block-end: calc(calc(var(--spacing) * 2) * calc(1 - var(--tw-space-y-reverse)))",
    ),
  )
  assert_true(
    output.contains(
      "margin-inline-start: calc(calc(var(--spacing) * -4) * var(--tw-space-x-reverse))",
    ),
  )
  assert_true(output.contains("margin-inline-start: 0"))
  assert_true(
    output.contains(
      "margin-inline-end: calc(1px * calc(1 - var(--tw-space-x-reverse)))",
    ),
  )
  assert_true(
    output.contains(":where(.space-x-reverse > :not(:last-child))") &&
    output.contains("--tw-space-x-reverse: 1"),
  )
  assert_true(output.contains("border-inline-style: var(--tw-border-style)"))
  assert_true(
    output.contains(
      "border-inline-end-width: calc(1px * calc(1 - var(--tw-divide-x-reverse)))",
    ),
  )
  assert_true(
    output.contains(
      "border-bottom-width: calc(4px * calc(1 - var(--tw-divide-y-reverse)))",
    ),
  )
  assert_true(output.contains("--tw-divide-y-reverse: 1"))
  assert_true(
    output.contains(":where(.divide-dashed > :not(:last-child))") &&
    output.contains("border-style: dashed"),
  )
  assert_true(output.contains("border-color: var(--color-brand)"))
  assert_true(
    output.contains(
      "border-color: color-mix(in oklab, var(--color-brand) 50%, transparent)",
    ),
  )
  assert_true(output.contains("@property --tw-space-x-reverse"))
  assert_true(output.contains("@property --tw-divide-y-reverse"))
}

///|
async test "placeholder utilities target the placeholder pseudo element" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme { --color-brand: oklch(60% .2 20); }
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build([
    "placeholder-brand", "placeholder-current", "placeholder-[#123456]", "focus:placeholder-brand",
  ])
  assert_true(output.contains(".placeholder-brand::placeholder"))
  assert_true(output.contains("color: var(--color-brand)"))
  assert_true(output.contains("color: currentcolor"))
  assert_true(output.contains("color: #123456"))
  assert_true(output.contains(".focus\\:placeholder-brand:focus::placeholder"))
}

///|
async test "variants rewrite both the candidate and the nested selector" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme { --spacing: 0.25rem; --breakpoint-md: 48rem; }
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build(["hover:space-x-4", "md:divide-y-2", "space-x-4!"])
  assert_true(
    output.contains(":where(.hover\\:space-x-4:hover > :not(:last-child))"),
  )
  assert_true(output.contains("@media (hover: hover)"))
  assert_true(
    output.contains(":where(.md\\:divide-y-2 > :not(:last-child))") &&
    output.contains("@media (width >= 48rem)"),
  )
  assert_true(output.contains("--tw-space-x-reverse: 0 !important"))
}
