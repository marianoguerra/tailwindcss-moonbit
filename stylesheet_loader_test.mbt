///|
async test "memory loader resolves imported theme files" {
  let loader = @tailwindcss.MemoryStylesheetLoader::new(files=[
    ("styles/theme.css", "@theme { --color-brand: #123456; }"),
  ])
  let compiler = @tailwindcss.compile(
    "@import \"theme.css\"; @tailwind utilities;",
    options=@tailwindcss.CompileOptions::new(base="styles", loader~),
  )
  inspect(
    compiler.build(["bg-brand"]),
    content=(
      #|:root, :host {
      #|  --color-brand: #123456;
      #|}
      #|.bg-brand {
      #|  background-color: var(--color-brand);
      #|}
      #|
    ),
  )
}

///|
async test "memory loader resolves nested imports relative to each file" {
  let loader = @tailwindcss.MemoryStylesheetLoader::new(files=[
    ("styles/a.css", "@import \"nested/b.css\";"),
    ("styles/nested/b.css", ".base { display: block; }"),
  ])
  let compiler = @tailwindcss.compile(
    "@import \"a.css\";",
    options=@tailwindcss.CompileOptions::new(base="styles", loader~),
  )
  inspect(
    compiler.build([]),
    content=(
      #|.base {
      #|  display: block;
      #|}
      #|
    ),
  )
}

///|
async test "memory loader leaves URL imports untouched" {
  let loader = @tailwindcss.MemoryStylesheetLoader::new()
  let compiler = @tailwindcss.compile(
    "@import url(\"https://example.com/a.css\");",
    options=@tailwindcss.CompileOptions::new(loader~),
  )
  inspect(
    compiler.build([]),
    content=(
      #|@import url("https://example.com/a.css");
      #|
    ),
  )
}

///|
async test "memory loader reports import cycles" {
  let loader = @tailwindcss.MemoryStylesheetLoader::new(files=[
    ("a.css", "@import \"b.css\";"),
    ("b.css", "@import \"a.css\";"),
  ])
  try
    @tailwindcss.compile(
      "@import \"a.css\";",
      options=@tailwindcss.CompileOptions::new(loader~),
    )
  catch {
    @tailwindcss.CompileError::ImportCycle(paths) =>
      debug_inspect(paths, content="[\"a.css\", \"b.css\", \"a.css\"]")
    error => abort("unexpected error: \{error}")
  } noraise {
    _ => fail("expected an import cycle")
  }
}

///|
async test "memory loader wraps import conditions" {
  let loader = @tailwindcss.MemoryStylesheetLoader::new(files=[
    ("example.css", "a { color: red; }"),
  ])
  let compiler = @tailwindcss.compile(
    "@import \"example.css\" layer(utilities) supports(display: grid) print;",
    options=@tailwindcss.CompileOptions::new(loader~),
  )
  inspect(
    compiler.build([]),
    content=(
      #|@supports (display: grid) {
      #|  @media print {
      #|    @layer utilities {
      #|      a {
      #|        color: red;
      #|      }
      #|    }
      #|  }
      #|}
      #|
    ),
  )
}
