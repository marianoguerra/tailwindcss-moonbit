///|
async test "CSS theme and spacing functions are substituted" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme { --spacing: 0.25rem; --color-brand: #123456; }
      #|.card {
      #|  margin: --spacing(4);
      #|  color: --theme(--color-brand);
      #|}
      #|
    ),
  )
  inspect(
    compiler.build([]),
    content=(
      #|:root, :host {
      #|  --spacing: 0.25rem;
      #|  --color-brand: #123456;
      #|}
      #|.card {
      #|  margin: calc(var(--spacing) * 4);
      #|  color: var(--color-brand);
      #|}
      #|
    ),
  )
}

///|
async test "theme functions inline inside conditional at-rules" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme { --breakpoint-wide: 80rem; }
      #|@media (width >= --theme(--breakpoint-wide)) {
      #|  .wide { display: block; }
      #|}
      #|
    ),
  )
  inspect(
    compiler.build([]),
    content=(
      #|@media (width >= 80rem) {
      #|  .wide {
      #|    display: block;
      #|  }
      #|}
      #|
    ),
  )
}

///|
async test "--alpha function validates its arguments" {
  try @tailwindcss.compile(".foo { color: --alpha(red); }") catch {
    @tailwindcss.CompileError::InvalidCss(message) =>
      assert_true(message.contains("--alpha()"))
    error => abort("unexpected error: \{error}")
  } noraise {
    _ => fail("expected invalid --alpha()")
  }
}

///|
async test "value functions recurse structurally and ignore quoted text" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme { --color-brand: #123456; }
      #|.example {
      #|  content: "theme(--color-brand)";
      #|  color: var(--fallback, --theme(--color-brand));
      #|}
      #|
    ),
  )
  inspect(
    compiler.build([]),
    content=(
      #|:root, :host {
      #|  --color-brand: #123456;
      #|}
      #|.example {
      #|  content: "theme(--color-brand)";
      #|  color: var(--fallback, var(--color-brand));
      #|}
      #|
    ),
  )
}
