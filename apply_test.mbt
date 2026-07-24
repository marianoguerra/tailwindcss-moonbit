///|
async test "@apply expands utilities inside rules" {
  let compiler = @tailwindcss.compile(
    "@theme { --spacing: 0.25rem; }\n.foo { @apply flex p-4; }",
  )
  inspect(
    compiler.build([]),
    content=(
      #|:root, :host {
      #|  --spacing: 0.25rem;
      #|}
      #|.foo {
      #|  display: flex;
      #|  padding: calc(var(--spacing) * 4);
      #|}
      #|
    ),
  )
}

///|
async test "@apply supports negative and important candidates" {
  let compiler = @tailwindcss.compile(
    "@theme { --spacing: 0.25rem; }\n.foo { @apply -m-2 flex!; }",
  )
  let output = compiler.build([])
  assert_true(output.contains("margin: calc(var(--spacing) * -2)"))
  assert_true(output.contains("display: flex !important"))
}

///|
async test "@apply rejects unknown candidates" {
  try @tailwindcss.compile(".foo { @apply not-a-utility; }") catch {
    @tailwindcss.CompileError::InvalidApplyCandidate(candidate) =>
      inspect(candidate, content="not-a-utility")
    error => abort("unexpected error: \{error}")
  } noraise {
    _ => fail("expected invalid @apply candidate")
  }
}

///|
async test "@apply expands variants into nested rules" {
  let compiler = @tailwindcss.compile(
    "@theme { --color-brand: #123456; }\n.foo { color: red; @apply hover:bg-brand; }",
  )
  let output = compiler.build([])
  assert_true(output.contains("&:hover"))
  assert_true(output.contains("@media (hover: hover)"))
  assert_true(output.contains("background-color: var(--color-brand)"))
}

///|
async test "@apply flattens rules that only carry nested content" {
  let compiler = @tailwindcss.compile(
    "@theme { --breakpoint-md: 48rem; }\n.foo { @apply md:flex hover:block; }",
  )
  inspect(
    compiler.build([]),
    content=(
      #|@media (hover: hover) {
      #|  .foo:hover {
      #|    display: block;
      #|  }
      #|}
      #|@media (width >= 48rem) {
      #|  .foo {
      #|    display: flex;
      #|  }
      #|}
      #|
    ),
  )
}
