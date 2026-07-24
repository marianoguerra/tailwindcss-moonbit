///|
/// Native command-line interface for the Tailwind CSS compiler.
///
/// Two modes:
///
/// - User mode: `tailwindcss -i <input.css> [-o <output.css>]
///   [-c <candidates.txt>] [--polyfills N]`. Reads the entry stylesheet, resolves
///   `@import`s from the filesystem, generates CSS for the class names in the
///   candidates file (one per line, empty if omitted), and writes the result to
///   `-o` or stdout.
///
/// - Batch mode: `tailwindcss --batch <separator> <input.css> <candidates.txt>...`.
///   Used by the differential test harness (`tools/diff/compare.mjs`); prints one
///   build per candidates file, separated by the given marker.
async fn main {
  let args = @sys.get_cli_args()
  if args.length() >= 2 && args[1] == "--batch" {
    run_batch(args)
  } else if args.length() >= 2 && args[1] == "bundle" {
    run_bundle(args)
  } else {
    run_cli(args)
  }
}

///|
fn usage() -> Unit {
  println(
    (
      #|usage: tailwindcss -i <input.css> [-o <output.css>] [-c <candidates.txt>] [--polyfills N]
      #|
      #|  -i, --input <file>       entry CSS file (required)
      #|  -o, --output <file>      write generated CSS here (default: stdout)
      #|  -c, --candidates <file>  newline-separated class names to generate
      #|      --polyfills <0..3>   0=none, 1=@property, 2=color-mix, 3=all (default)
      #|  -h, --help               show this help
      #|
      #|  tailwindcss bundle -i <input.css> [-o <bundle.json>]
      #|      resolve every @import from the filesystem and write a JSON
      #|      path->content map usable as a compile request's `imports` field
      #|
      #|  tailwindcss --batch <separator> <input.css> <candidates.txt>...
      #|      differential-test harness mode
    ),
  )
}

///|
/// Read a candidates file into a trimmed, non-empty list of class names.
fn read_candidates(path : String) -> Array[String] raise {
  @fs.read_file_to_string(path)
  .split("\n")
  .map(fn(line) { line.trim().to_owned() })
  .filter(fn(line) { line != "" })
  .collect()
}

///|
/// The directory portion of a path, used as the `@import` resolution base.
fn base_of(path : String) -> String {
  match path.rev_split_once("/") {
    Some((parent, _)) => parent.to_owned()
    None => ""
  }
}

///|
async fn run_cli(args : Array[String]) -> Unit {
  let mut input : String? = None
  let mut output : String? = None
  let mut candidates_file : String? = None
  let mut polyfills = @tw.POLYFILL_ALL
  let mut index = 1
  while index < args.length() {
    let arg = args[index]
    match arg {
      "-h" | "--help" => {
        usage()
        return
      }
      "-i" | "--input" => {
        index += 1
        guard index < args.length() else {
          println("error: \{arg} requires a value")
          @sys.exit(2)
        }
        input = Some(args[index])
      }
      "-o" | "--output" => {
        index += 1
        guard index < args.length() else {
          println("error: \{arg} requires a value")
          @sys.exit(2)
        }
        output = Some(args[index])
      }
      "-c" | "--candidates" => {
        index += 1
        guard index < args.length() else {
          println("error: \{arg} requires a value")
          @sys.exit(2)
        }
        candidates_file = Some(args[index])
      }
      "--polyfills" => {
        index += 1
        guard index < args.length() else {
          println("error: \{arg} requires a value")
          @sys.exit(2)
        }
        polyfills = @string.parse_int(args[index]) catch {
          _ => {
            println("error: --polyfills expects an integer 0..3")
            @sys.exit(2)
            @tw.POLYFILL_ALL
          }
        }
      }
      _ => {
        println("error: unknown argument: \{arg}")
        usage()
        @sys.exit(2)
      }
    }
    index += 1
  }
  guard input is Some(input_path) else {
    println("error: -i/--input is required")
    usage()
    @sys.exit(2)
  }
  let css = @fs.read_file_to_string(input_path) catch {
    _ => {
      println("error: cannot read input file: \{input_path}")
      @sys.exit(1)
      ""
    }
  }
  let loader = @twfs.FsStylesheetLoader::new()
  let compiler = @tw.compile(
    css,
    options=@tw.CompileOptions::new(
      base=base_of(input_path),
      from=input_path,
      loader~,
      polyfills~,
    ),
  )
  let candidates = match candidates_file {
    Some(path) =>
      read_candidates(path) catch {
        _ => {
          println("error: cannot read candidates file: \{path}")
          @sys.exit(1)
          []
        }
      }
    None => []
  }
  let result = compiler.build(candidates)
  match output {
    Some(path) => @fs.write_string_to_file(path, result)
    None => println(result)
  }
}

///|
/// `--batch <separator> <input.css> <candidates.txt>...` — the harness entry point
/// consumed by `tools/diff/compare.mjs`. One build per candidates file, joined by
/// the separator on its own line. Preserved verbatim so the byte-exact diff cases
/// keep passing.
async fn run_batch(args : Array[String]) -> Unit {
  if args.length() < 5 {
    println(
      "usage: tailwindcss --batch <separator> <input.css> <candidates.txt>...",
    )
    @sys.exit(2)
  }
  let separator = args[2]
  let input_path = args[3]
  let css = @fs.read_file_to_string(input_path)
  let loader = @twfs.FsStylesheetLoader::new()
  let compiler = @tw.compile(
    css,
    options=@tw.CompileOptions::new(
      base=base_of(input_path),
      from=input_path,
      loader~,
      polyfills=@tw.POLYFILL_ALL,
    ),
  )
  let first_candidates = 4
  for index in first_candidates..<args.length() {
    if index > first_candidates {
      println(separator)
    }
    println(compiler.build(read_candidates(args[index])))
  }
}

///|
/// `bundle -i <input.css> [-o <bundle.json>]` — resolve the entry's `@import`
/// graph from the filesystem and emit a JSON `path -> content` map. The keys are
/// the same lexical paths the in-memory loader uses for lookup, so the map can be
/// handed straight to a compile request's `imports` field (with the entry compiled
/// at the default `base = ""`).
async fn run_bundle(args : Array[String]) -> Unit {
  let mut input : String? = None
  let mut output : String? = None
  let mut index = 2
  while index < args.length() {
    let arg = args[index]
    match arg {
      "-h" | "--help" => {
        usage()
        return
      }
      "-i" | "--input" => {
        index += 1
        guard index < args.length() else {
          println("error: \{arg} requires a value")
          @sys.exit(2)
        }
        input = Some(args[index])
      }
      "-o" | "--output" => {
        index += 1
        guard index < args.length() else {
          println("error: \{arg} requires a value")
          @sys.exit(2)
        }
        output = Some(args[index])
      }
      _ => {
        println("error: unknown argument: \{arg}")
        usage()
        @sys.exit(2)
      }
    }
    index += 1
  }
  guard input is Some(input_path) else {
    println("error: bundle requires -i/--input")
    usage()
    @sys.exit(2)
  }
  let css = @fs.read_file_to_string(input_path) catch {
    _ => {
      println("error: cannot read input file: \{input_path}")
      @sys.exit(1)
      ""
    }
  }
  let loader = @twfs.FsStylesheetLoader::new()
  let imports = @tw.collect_imports(css, loader, base=base_of(input_path)) catch {
    err => {
      println("error: \{err}")
      @sys.exit(1)
      Map([])
    }
  }
  let json = imports_to_json(imports)
  match output {
    Some(path) => @fs.write_string_to_file(path, json)
    None => println(json)
  }
}

///|
/// Serialize the collected import map to a JSON object with keys sorted, so the
/// output is stable across runs (`Map` iteration order is unspecified). Built as a
/// string rather than via `Json::object` so the sorted order survives; values and
/// keys are escaped by round-tripping through `Json::string(...).stringify()`.
fn imports_to_json(imports : Map[String, String]) -> String {
  let keys = imports.keys().collect()
  keys.sort()
  let parts = keys.map(fn(key) {
    let value = imports.get(key).unwrap()
    "\{Json::string(key).stringify()}:\{Json::string(value).stringify()}"
  })
  "{\{parts.join(",")}}"
}
