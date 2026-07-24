///|
async test "simple sizing spacing order and flex utility families" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme {
      #|  --spacing: 0.25rem;
      #|  --container-sm: 24rem;
      #|  --columns-card: 18rem;
      #|  --order-first: -9999;
      #|  --flex-basis-card: 20rem;
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build([
    "line-clamp-3", "columns-card", "w-sm", "w-1/2", "size-2/3", "inline-4", "scroll-m-4",
    "-scroll-ms-2", "scroll-pbe-px", "order-first", "-order-2", "flex-[2_2_10%]",
    "basis-1/2", "basis-card", "grow", "shrink-0", "border-spacing-x-4",
  ])
  assert_true(output.contains("-webkit-line-clamp: 3"))
  assert_true(output.contains("columns: var(--columns-card)"))
  assert_true(output.contains("width: var(--container-sm)"))
  assert_true(output.contains("width: calc(1 / 2 * 100%)"))
  assert_true(output.contains("height: calc(2 / 3 * 100%)"))
  assert_true(output.contains("inline-size: calc(var(--spacing) * 4)"))
  assert_true(output.contains("scroll-margin: calc(var(--spacing) * 4)"))
  assert_true(
    output.contains("scroll-margin-inline-start: calc(var(--spacing) * -2)"),
  )
  assert_true(output.contains("scroll-padding-block-end: 1px"))
  assert_true(output.contains("order: var(--order-first)"))
  assert_true(output.contains("order: calc(2 * -1)"))
  assert_true(output.contains("flex: 2 2 10%"))
  assert_true(output.contains("flex-basis: calc(1 / 2 * 100%)"))
  assert_true(output.contains("flex-basis: var(--flex-basis-card)"))
  assert_true(output.contains("flex-grow: 1"))
  assert_true(output.contains("flex-shrink: 0"))
  assert_true(output.contains("@property --tw-border-spacing-x"))
}

///|
async test "simple list opacity blend and form-control utility families" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme {
      #|  --list-style-type-square: square;
      #|  --list-style-image-check: url(check.svg);
      #|  --opacity-dim: 0.35;
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build([
    "list-square", "list-image-check", "opacity-50", "opacity-[.12]", "opacity-dim",
    "bg-blend-multiply", "mix-blend-plus-lighter", "scheme-only-dark", "forced-color-adjust-none",
    "align-[3px]", "tab-4",
  ])
  assert_true(output.contains("list-style-type: var(--list-style-type-square)"))
  assert_true(
    output.contains("list-style-image: var(--list-style-image-check)"),
  )
  assert_true(output.contains("opacity: 50%"))
  assert_true(output.contains("opacity: .12"))
  assert_true(output.contains("opacity: var(--opacity-dim)"))
  assert_true(output.contains("background-blend-mode: multiply"))
  assert_true(output.contains("mix-blend-mode: plus-lighter"))
  assert_true(output.contains("color-scheme: only dark"))
  assert_true(output.contains("forced-color-adjust: none"))
  assert_true(output.contains("vertical-align: 3px"))
  assert_true(output.contains("tab-size: 4"))
}
