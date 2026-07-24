///|
fn normalize_path(path : String) -> String {
  let absolute = path.has_prefix("/")
  let parts : Array[String] = []
  for raw in path.split("/") {
    let part = raw.to_owned()
    match part {
      "" | "." => ()
      ".." =>
        if !parts.is_empty() && parts.last() != Some("..") {
          ignore(parts.pop())
        } else if !absolute {
          parts.push(part)
        }
      _ => parts.push(part)
    }
  }
  let normalized = parts.join("/")
  if absolute {
    "/\{normalized}"
  } else {
    normalized
  }
}

///|
fn dirname(path : String) -> String {
  match path.rev_split_once("/") {
    Some((parent, _)) => parent.to_owned()
    None => ""
  }
}

///|
fn resolve_path(base : String, id : String) -> String {
  if id.has_prefix("/") {
    normalize_path(id)
  } else if base == "" {
    normalize_path(id)
  } else {
    normalize_path("\{base}/\{id}")
  }
}

///|
/// An asynchronous in-memory stylesheet loader.
///
/// Paths are normalized on insertion and lookup. This makes it suitable for
/// deterministic tests and hosts without filesystem access.
pub struct MemoryStylesheetLoader {
  files : Map[String, String]
}

///|
pub fn MemoryStylesheetLoader::new(
  files? : Array[(String, String)] = [],
) -> MemoryStylesheetLoader {
  let normalized : Map[String, String] = Map([])
  for entry in files {
    let (path, content) = entry
    normalized[normalize_path(path)] = content
  }
  { files: normalized }
}

///|
pub fn MemoryStylesheetLoader::add(
  self : MemoryStylesheetLoader,
  path : String,
  content : String,
) -> Unit {
  self.files[normalize_path(path)] = content
}

///|
fn MemoryStylesheetLoader::resolve(
  self : MemoryStylesheetLoader,
  id : String,
  base : String,
) -> LoadedStylesheet raise CompileError {
  let path = resolve_path(base, id)
  match self.files.get(path) {
    Some(content) => { content, path, base: dirname(path) }
    None => raise StylesheetNotFound(path)
  }
}

///|
pub impl StylesheetLoader for MemoryStylesheetLoader with fn load(
  self,
  id,
  base,
) {
  self.resolve(id, base)
}

///|
pub impl SyncStylesheetLoader for MemoryStylesheetLoader with fn load(
  self,
  id,
  base,
) {
  self.resolve(id, base)
}
