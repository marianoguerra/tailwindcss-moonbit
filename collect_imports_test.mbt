///|
/// `collect_imports` returns every transitively imported file once, keyed by the
/// same lexical path the loader uses for lookup; a diamond import is deduped.
async test "collect_imports gathers the transitive graph and dedupes" {
  let loader = @tailwindcss.MemoryStylesheetLoader::new(files=[
    ("a.css", "@import \"shared/theme.css\"; .a { color: red; }"),
    ("shared/theme.css", "@theme { --color-brand: #123456; }"),
  ])
  let entry = "@import \"a.css\"; @import \"shared/theme.css\"; @tailwind utilities;"
  let imports = @tailwindcss.collect_imports(entry, loader)
  let keys = imports.keys().collect()
  keys.sort()
  debug_inspect(keys, content="[\"a.css\", \"shared/theme.css\"]")
}

///|
/// The collected map, replayed through a fresh `MemoryStylesheetLoader`, resolves
/// the entry identically to the original loader — the whole point of the bundle.
async test "collect_imports round-trips through compile" {
  let loader = @tailwindcss.MemoryStylesheetLoader::new(files=[
    ("a.css", "@import \"shared/theme.css\"; .a { color: red; }"),
    ("shared/theme.css", "@theme { --color-brand: #123456; }"),
  ])
  let entry = "@import \"a.css\"; @tailwind utilities;"
  let direct = @tailwindcss.compile(
      entry,
      options=@tailwindcss.CompileOptions::new(loader~),
    ).build(["bg-brand"])

  // Rebuild a loader from the collected map and compile the same entry.
  let imports = @tailwindcss.collect_imports(entry, loader)
  let replay = @tailwindcss.MemoryStylesheetLoader::new()
  for path, content in imports {
    replay.add(path, content)
  }
  let round = @tailwindcss.compile(
      entry,
      options=@tailwindcss.CompileOptions::new(loader=replay),
    ).build(["bg-brand"])
  assert_eq(round, direct)
}

///|
/// A cycle in the graph is reported rather than looping forever.
async test "collect_imports reports import cycles" {
  let loader = @tailwindcss.MemoryStylesheetLoader::new(files=[
    ("a.css", "@import \"b.css\";"),
    ("b.css", "@import \"a.css\";"),
  ])
  try @tailwindcss.collect_imports("@import \"a.css\";", loader) catch {
    @tailwindcss.CompileError::ImportCycle(paths) =>
      debug_inspect(paths, content="[\"a.css\", \"b.css\", \"a.css\"]")
    error => abort("unexpected error: \{error}")
  } noraise {
    _ => fail("expected an import cycle")
  }
}
