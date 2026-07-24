///|
async test "@utility bodies may contain nested rules and at-rules" {
  let compiler = @tailwindcss.compile(
    (
      #|@utility card { &:hover { color: red } }
      #|@utility framed { @media print { border: 1px solid } }
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build(["card", "framed", "hover:card"])
  assert_true(output.contains(".card:hover"))
  assert_true(output.contains("@media print"))
  assert_true(output.contains(".hover\\:card:hover:hover"))
}

///|
async test "@utility bodies may use @apply" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme { --spacing: 0.25rem; }
      #|@utility base { @apply flex p-4; }
      #|@utility fancy { @apply base; color: red; }
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build(["fancy"])
  assert_true(output.contains("display: flex"))
  assert_true(output.contains("padding: calc(var(--spacing) * 4)"))
  assert_true(output.contains("color: red"))
}

///|
async test "@utility reports circular @apply" {
  try
    @tailwindcss.compile("@utility loop { @apply loop; }\n@tailwind utilities;")
  catch {
    @tailwindcss.CompileError::InvalidCss(message) =>
      assert_true(message.contains("circular dependency"))
    error => abort("unexpected error: \{error}")
  } noraise {
    _ => fail("expected a circular dependency error")
  }
}

///|
async test "@utility rejects invalid names" {
  try @tailwindcss.compile("@utility Bad { color: red }") catch {
    @tailwindcss.CompileError::InvalidCss(_) => ()
    error => abort("unexpected error: \{error}")
  } noraise {
    _ => fail("expected an invalid utility name error")
  }
  try @tailwindcss.compile("@utility a-*-b { color: red }") catch {
    @tailwindcss.CompileError::InvalidCss(_) => ()
    error => abort("unexpected error: \{error}")
  } noraise {
    _ => fail("expected an invalid utility name error")
  }
}

///|
async test "@variant substitutes stylesheet blocks" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme { --breakpoint-md: 48rem; }
      #|@variant hover { .a { color: red } }
      #|@variant md { .b { color: blue } }
      #|@variant hover, focus { .c { color: green } }
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build([])
  assert_true(output.contains(":scope:hover .a"))
  assert_true(output.contains("@media (width >= 48rem)"))
  assert_true(output.contains(".b"))
  assert_true(output.contains(":scope:hover .c"))
  assert_true(output.contains(":scope:focus .c"))
}

///|
async test "@variant rejects unknown variants" {
  try @tailwindcss.compile("@variant nope { .a { color: red } }") catch {
    @tailwindcss.CompileError::InvalidCss(message) =>
      assert_true(message.contains("nope"))
    error => abort("unexpected error: \{error}")
  } noraise {
    _ => fail("expected an unknown variant error")
  }
}

///|
async test "@custom-variant accepts at-rule branches and validates names" {
  let compiler = @tailwindcss.compile(
    (
      #|@custom-variant any (@media print, &:hover);
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build(["any:flex"])
  assert_true(output.contains(".any\\:flex:hover"))
  assert_true(output.contains("@media print"))
  try @tailwindcss.compile("@custom-variant Bad (&:hover);") catch {
    @tailwindcss.CompileError::InvalidCss(_) => ()
    error => abort("unexpected error: \{error}")
  } noraise {
    _ => fail("expected an invalid variant name error")
  }
  try @tailwindcss.compile("@custom-variant lonely;") catch {
    @tailwindcss.CompileError::InvalidCss(message) =>
      assert_true(message.contains("no selector or body"))
    error => abort("unexpected error: \{error}")
  } noraise {
    _ => fail("expected a missing selector or body error")
  }
}

///|
async test "nested user rules are flattened" {
  let compiler = @tailwindcss.compile(
    (
      #|.a { .b { color: red } }
      #|.c, .d { &:hover { color: blue } }
      #|.e { @media print { color: green } }
      #|.f { }
      #|@tailwind utilities;
      #|
    ),
  )
  inspect(
    compiler.build([]),
    content=(
      #|.a .b {
      #|  color: red;
      #|}
      #|:is(.c, .d):hover {
      #|  color: blue;
      #|}
      #|@media print {
      #|  .e {
      #|    color: green;
      #|  }
      #|}
      #|
    ),
  )
}
