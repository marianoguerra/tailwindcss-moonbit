///|
/// The margaui stylesheet graph, parsed on the first call and reused after.
///
/// Safe to share because `css` only calls `Compiler::render`, which never
/// mutates it.
let compiler : Ref[@tw.Compiler?] = Ref(None)

///|
/// Compile margaui + Tailwind for `classes`, a whitespace-separated list of
/// class names, and return the CSS those classes need.
///
/// The result depends on the argument alone: the cached compiler renders each
/// call's candidates without accumulating them. Errors come back as a CSS
/// comment, so the host always gets a string.
pub fn css(classes : String) -> String {
  let candidates = []
  for token in classes.split(" ") {
    for part in token.split("\n") {
      let name = part.trim().to_owned()
      if name != "" {
        candidates.push(name)
      }
    }
  }
  let parsed = match compiler.val {
    Some(parsed) => parsed
    None => {
      let parsed = @tw.compile_sync(
        entry_css,
        options=@tw.CompileOptions::new(
          from="entry.css",
          sync_loader=@tw.MemoryStylesheetLoader::new(files=imports),
        ),
      ) catch {
        err => return "/* tailwindcss compile error: " + err.to_string() + " */"
      }
      compiler.val = Some(parsed)
      parsed
    }
  }
  parsed.render(candidates)
}
