///|
async test "theme options control resolution and emission" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme { --color-default: #111; --color-unused: #999; }
      #|@theme inline { --color-inline: #222; }
      #|@theme static { --color-static: #333; --color-static-unused: #444; }
      #|@theme reference { --color-reference: #555; }
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build([
    "bg-default", "bg-inline", "bg-static", "bg-reference",
  ])
  assert_true(output.contains("--color-default: #111"))
  assert_false(output.contains("--color-unused: #999"))
  assert_true(output.contains("--color-static-unused: #444"))
  assert_true(output.contains("background-color: #222"))
  assert_true(output.contains("background-color: var(--color-reference, #555)"))
  assert_false(output.contains("--color-reference: #555"))
}

///|
async test "theme prefixes candidates and generated variables" {
  let compiler = @tailwindcss.compile(
    "@theme prefix(tw) { --color-brand: #123456; --spacing: 0.25rem; }\n@tailwind utilities;",
  )
  let output = compiler.build([
    "bg-brand", "hover:tw:bg-brand", "tw:bg-brand", "tw:p-4", "tw:hover:bg-brand",
  ])
  assert_false(output.contains(".bg-brand"))
  assert_false(output.contains(".hover\\:tw\\:bg-brand"))
  assert_true(output.contains(".tw\\:bg-brand"))
  assert_true(output.contains("var(--tw-color-brand)"))
  assert_true(output.contains("calc(var(--tw-spacing) * 4)"))
}

///|
async test "theme wildcard resets dependencies and keyframes" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme { --color-red: red; --color-blue: blue; }
      #|@theme {
      #|  --color-*: initial;
      #|  --color-base: #123456;
      #|  --color-brand: var(--color-base);
      #|  --animate-spin: spin 1s linear infinite;
      #|  --animate-unused: unused 2s;
      #|  @keyframes spin { to { transform: rotate(360deg); } }
      #|  @keyframes unused { to { opacity: 0; } }
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build(["bg-red", "bg-blue", "bg-brand", "animate-spin"])
  assert_false(output.contains("--color-red"))
  assert_false(output.contains("--color-blue"))
  assert_true(output.contains("--color-base: #123456"))
  assert_true(output.contains("--color-brand: var(--color-base)"))
  assert_true(output.contains("@keyframes spin"))
  assert_false(output.contains("@keyframes unused"))
}
