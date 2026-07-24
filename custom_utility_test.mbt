///|
async test "static @utility participates in build and @apply" {
  let compiler = @tailwindcss.compile(
    (
      #|@utility tab-4 { tab-size: 4; }
      #|.editor { @apply tab-4; }
      #|@tailwind utilities;
      #|
    ),
  )
  inspect(
    compiler.build(["tab-4"]),
    content=(
      #|.editor {
      #|  tab-size: 4;
      #|}
      #|.tab-4 {
      #|  tab-size: 4;
      #|}
      #|
    ),
  )
}

///|
async test "functional @utility resolves bare and arbitrary values" {
  let compiler = @tailwindcss.compile(
    (
      #|@utility tab-* {
      #|  tab-size: --value(integer);
      #|  tab-size: --value([integer]);
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  inspect(
    compiler.build(["tab-4", "tab-[8]", "tab-auto"]),
    content=(
      #|.tab-4 {
      #|  tab-size: 4;
      #|}
      #|.tab-\[8\] {
      #|  tab-size: 8;
      #|}
      #|
    ),
  )
}

///|
async test "functional @utility resolves theme values and works in @apply" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme { --tab-size-github: 8; }
      #|@utility tab-* { tab-size: --value(--tab-size-*); }
      #|.editor { @apply tab-github; }
      #|@tailwind utilities;
      #|
    ),
  )
  inspect(
    compiler.build(["tab-github"]),
    content=(
      #|:root, :host {
      #|  --tab-size-github: 8;
      #|}
      #|.editor {
      #|  tab-size: var(--tab-size-github);
      #|}
      #|.tab-github {
      #|  tab-size: var(--tab-size-github);
      #|}
      #|
    ),
  )
}

///|
async test "functional @utility constrains number and percentage values" {
  let compiler = @tailwindcss.compile(
    (
      #|@utility metric-* {
      #|  number: --value(number);
      #|  percentage: --value(percentage);
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build([
    "metric-0", "metric-1.5", "metric-20%", "metric-1.23",
  ])
  assert_true(output.contains(".metric-0"))
  assert_true(output.contains("number: 0"))
  assert_true(output.contains(".metric-1\\.5"))
  assert_true(output.contains("number: 1.5"))
  assert_true(output.contains(".metric-20\\%"))
  assert_true(output.contains("percentage: 20%"))
  assert_false(output.contains("metric-1\\.23"))
}

///|
async test "functional @utility resolves defaults and modifiers" {
  let compiler = @tailwindcss.compile(
    (
      #|@utility example-* {
      #|  value: --value(integer, --default(12));
      #|  modifier: --modifier(integer, --default(34));
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  inspect(
    compiler.build([
      "example", "example/1", "example-2", "example-2/3", "example-2/nope",
    ]),
    content=(
      #|.example {
      #|  value: 12;
      #|  modifier: 34;
      #|}
      #|.example-2 {
      #|  value: 2;
      #|  modifier: 34;
      #|}
      #|.example-2\/3 {
      #|  value: 2;
      #|  modifier: 3;
      #|}
      #|.example\/1 {
      #|  value: 12;
      #|  modifier: 1;
      #|}
      #|
    ),
  )
}

///|
async test "functional @utility resolves ratios" {
  let compiler = @tailwindcss.compile(
    (
      #|@utility custom-aspect-* {
      #|  ratio: --value(ratio, [ratio]);
      #|  number: --value(number);
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  inspect(
    compiler.build([
      "custom-aspect-1/2", "custom-aspect-[7/9]", "custom-aspect-2",
    ]),
    content=(
      #|.custom-aspect-1\/2 {
      #|  ratio: 1 / 2;
      #|}
      #|.custom-aspect-2 {
      #|  number: 2;
      #|}
      #|.custom-aspect-\[7\/9\] {
      #|  ratio: 7/9;
      #|}
      #|
    ),
  )
}

///|
async test "functional @utility resolves nested theme keys and variables" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme {
      #|  --text-xs: 0.75rem;
      #|  --text-xs--line-height: 1rem;
      #|}
      #|@utility token-* { value: --value([*]); }
      #|@utility type-* {
      #|  font-size: --value(--text);
      #|  line-height: --value(--text-* --line-height);
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build(["type-xs", "token-(--custom-token)"])
  assert_true(output.contains("font-size: var(--text-xs)"))
  assert_true(output.contains("line-height: var(--text-xs--line-height)"))
  assert_true(output.contains("value: var(--custom-token)"))
}

///|
async test "functional @utility enforces typed arbitrary hints" {
  let compiler = @tailwindcss.compile(
    (
      #|@utility typed-* {
      #|  integer: --value([integer]);
      #|  color: --value([color]);
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build([
    "typed-[integer:var(--count)]", "typed-(integer:--other-count)", "typed-[color:var(--paint)]",
    "typed-[length:var(--size)]",
  ])
  assert_true(output.contains("integer: var(--count)"))
  assert_true(output.contains("integer: var(--other-count)"))
  assert_true(output.contains("color: var(--paint)"))
  assert_false(output.contains("--size"))
}
