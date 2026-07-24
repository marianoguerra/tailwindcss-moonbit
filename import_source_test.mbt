///|
async test "nested imports propagate their base to @source" {
  let loader = @tailwindcss.MemoryStylesheetLoader::new(files=[
    ("styles/nested/a.css", "@source \"./inner.html\";"),
  ])
  let compiler = @tailwindcss.compile(
    "@source \"./root.html\";\n@import \"nested/a.css\";",
    options=@tailwindcss.CompileOptions::new(base="styles", loader~),
  )
  let sources = compiler.sources()
  assert_eq(sources.length(), 2)
  assert_eq(sources[0].base, "styles")
  assert_eq(sources[0].pattern, "./root.html")
  assert_eq(sources[1].base, "styles/nested")
  assert_eq(sources[1].pattern, "./inner.html")
}

///|
async test "import conditions wrap the imported stylesheet" {
  let loader = @tailwindcss.MemoryStylesheetLoader::new(files=[
    ("a.css", "@theme { --color-brand: #123456; }\n.x { color: red }"),
  ])
  let compiler = @tailwindcss.compile(
    "@import \"a.css\" layer(base) supports(display:grid) print;\n@tailwind utilities;",
    options=@tailwindcss.CompileOptions::new(loader~),
  )
  inspect(
    compiler.build(["bg-brand"]),
    content=(
      #|@supports (display:grid) {
      #|  @media print {
      #|    @layer base {
      #|      :root, :host {
      #|        --color-brand: #123456;
      #|      }
      #|      .x {
      #|        color: red;
      #|      }
      #|    }
      #|  }
      #|}
      #|.bg-brand {
      #|  background-color: var(--color-brand);
      #|}
      #|
    ),
  )
}

///|
async test "reference imports contribute only theme variables" {
  let loader = @tailwindcss.MemoryStylesheetLoader::new(files=[
    ("a.css", "@theme { --color-brand: #123456; }\n.x { color: red }"),
  ])
  for
    source in [
      "@reference \"a.css\";\n@tailwind utilities;", "@import \"a.css\" reference;\n@tailwind utilities;",
    ] {
    let compiler = @tailwindcss.compile(
      source,
      options=@tailwindcss.CompileOptions::new(loader~),
    )
    inspect(
      compiler.build(["bg-brand"]),
      content=(
        #|.bg-brand {
        #|  background-color: var(--color-brand, #123456);
        #|}
        #|
      ),
    )
  }
}

///|
async test "theme(reference) imports must only contain theme blocks" {
  let loader = @tailwindcss.MemoryStylesheetLoader::new(files=[
    ("a.css", "@theme { --color-brand: #123456; }\n.x { color: red }"),
    ("b.css", "@theme { --color-brand: #123456; }"),
  ])
  try
    @tailwindcss.compile(
      "@import \"a.css\" theme(reference);",
      options=@tailwindcss.CompileOptions::new(loader~),
    )
  catch {
    @tailwindcss.CompileError::InvalidCss(message) =>
      assert_true(message.contains("theme(reference)"))
    error => abort("unexpected error: \{error}")
  } noraise {
    _ => fail("expected a theme(reference) error")
  }
  let compiler = @tailwindcss.compile(
    "@import \"b.css\" theme(reference);\n@tailwind utilities;",
    options=@tailwindcss.CompileOptions::new(loader~),
  )
  assert_true(
    compiler.build(["bg-brand"]).contains("var(--color-brand, #123456)"),
  )
}

///|
async test "import cycles are rejected" {
  let loader = @tailwindcss.MemoryStylesheetLoader::new(files=[
    ("c1.css", "@import \"c2.css\";"),
    ("c2.css", "@import \"c1.css\";"),
  ])
  try
    @tailwindcss.compile(
      "@import \"c1.css\";",
      options=@tailwindcss.CompileOptions::new(loader~),
    )
  catch {
    @tailwindcss.CompileError::ImportCycle(cycle) =>
      assert_eq(cycle, ["c1.css", "c2.css", "c1.css"])
    error => abort("unexpected error: \{error}")
  } noraise {
    _ => fail("expected an import cycle error")
  }
}

///|
async test "JavaScript configuration directives are rejected" {
  for source in ["@plugin \"x\";", "@config \"tailwind.config.js\";"] {
    try @tailwindcss.compile(source) catch {
      @tailwindcss.CompileError::UnsupportedJsCompatibility(_) => ()
      error => abort("unexpected error: \{error}")
    } noraise {
      _ => fail("expected an unsupported JavaScript compatibility error")
    }
  }
}
