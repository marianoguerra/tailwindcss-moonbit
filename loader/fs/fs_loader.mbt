///|
/// Native filesystem implementation of Tailwind's stylesheet loader.
pub struct FsStylesheetLoader(Unit)

///|
pub fn FsStylesheetLoader::new() -> FsStylesheetLoader {
  FsStylesheetLoader(())
}

///|
pub impl @tw.StylesheetLoader for FsStylesheetLoader with fn load(
  _self,
  id,
  base,
) {
  let requested = if id.has_prefix("/") {
    id
  } else if base == "" {
    id
  } else {
    "\{base}/\{id}"
  }
  try {
    let path = @afs.realpath(requested)
    let content = @afs.read_file(path).text()
    {
      content,
      path,
      base: match path.rev_split_once("/") {
        Some((parent, _)) => parent.to_owned()
        None => ""
      },
    }
  } catch {
    _ => raise StylesheetNotFound(requested)
  }
}
