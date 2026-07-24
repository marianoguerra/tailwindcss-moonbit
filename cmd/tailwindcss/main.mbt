///|
async fn main {
  let args = @sys.get_cli_args()
  if args.length() < 3 {
    println(
      "usage: tailwindcss <input.css> <candidates.txt> | tailwindcss --batch <separator> <input.css> <candidates.txt>...",
    )
    @sys.exit(2)
  }
  let polyfill_flag = args[1] == "--polyfills"
  let polyfills = if polyfill_flag {
    @string.parse_int(args[2]) catch {
      _ => @tw.POLYFILL_ALL
    }
  } else {
    @tw.POLYFILL_ALL
  }
  let batch = args[1] == "--batch"
  let input_index = if batch || polyfill_flag { 3 } else { 1 }
  if batch && args.length() < 5 {
    println(
      "usage: tailwindcss --batch <separator> <input.css> <candidates.txt>...",
    )
    @sys.exit(2)
  }
  let css = @fs.read_file_to_string(args[input_index])
  let base = match args[input_index].rev_split_once("/") {
    Some((parent, _)) => parent.to_owned()
    None => ""
  }
  let loader = @twfs.FsStylesheetLoader::new()
  let compiler = @tw.compile(
    css,
    options=@tw.CompileOptions::new(
      base~,
      from=args[input_index],
      loader~,
      polyfills~,
    ),
  )
  let first_candidates = if batch { 4 } else if polyfill_flag { 4 } else { 2 }
  for index in first_candidates..<args.length() {
    if batch && index > first_candidates {
      println(args[2])
    }
    let candidates = @fs.read_file_to_string(args[index])
      .split("\n")
      .map(fn(line) { line.trim().to_owned() })
      .filter(fn(line) { line != "" })
      .collect()
    println(compiler.build(candidates))
  }
}
