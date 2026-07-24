//! `twc` — a tiny demo CLI that compiles Tailwind CSS v4 utility classes by
//! calling the `tw-mb` compiler built as a **WebAssembly Component**.
//!
//! The heavy lifting lives entirely in the wasm component
//! (`tw-compiler.component.wasm`, produced by `./build-component.sh`); this Rust
//! program is just the host: it parses args, builds a JSON compile request,
//! calls the component's `compile-css-json` export via wasmtime, and prints the
//! generated CSS.
//!
//! Usage:
//!   twc [options] <class>...
//!
//!   <class>...              utility class names to generate (e.g. flex p-4 hover:bg-black)
//!   --bundle <file>         JSON `{path:content}` import map produced by
//!                           `tailwindcss bundle -i entry.css -o bundle.json`
//!   --css <string>          entry stylesheet source (default: `@import "tailwindcss";`)
//!   --css-file <file>       read the entry stylesheet from a file instead
//!   --polyfills <0..3>      0=none 1=@property 2=color-mix 3=all (default 3)
//!   --from <path>           logical path of the entry stylesheet (default input.css)
//!   -h, --help              show this help
//!
//! The component wasm is located via the `TW_COMPILER_WASM` env var, falling
//! back to `tw-compiler.component.wasm` next to this crate.

use anyhow::{bail, Context, Result};
use serde_json::{json, Value};
use wasmtime::component::{Component, Linker};
use wasmtime::{Engine, Store};

wasmtime::component::bindgen!({
    world: "compiler",
    path: "wit/world.wit",
});

const DEFAULT_ENTRY_CSS: &str = "@import \"tailwindcss\";";

struct Args {
    classes: Vec<String>,
    bundle: Option<String>,
    css: Option<String>,
    css_file: Option<String>,
    polyfills: i64,
    from: String,
}

fn print_help() {
    print!(
        "{}",
        r#"twc — compile Tailwind classes via the tw-mb wasm component

USAGE:
    twc [options] <class>...

ARGS:
    <class>...            utility class names to generate (e.g. flex p-4 hover:bg-black)

OPTIONS:
    --bundle <file>       JSON {path:content} import map from `tailwindcss bundle`
    --css <string>        entry stylesheet source (default: `@import "tailwindcss";`)
    --css-file <file>     read the entry stylesheet from a file
    --polyfills <0..3>    0=none 1=@property 2=color-mix 3=all (default 3)
    --from <path>         logical path of the entry stylesheet (default input.css)
    -h, --help            show this help

ENV:
    TW_COMPILER_WASM      path to the component wasm (default: bundled sibling)
"#
    );
}

fn parse_args() -> Result<Option<Args>> {
    let mut classes = Vec::new();
    let mut bundle = None;
    let mut css = None;
    let mut css_file = None;
    let mut polyfills = 3i64;
    let mut from = "input.css".to_string();

    let mut it = std::env::args().skip(1);
    while let Some(arg) = it.next() {
        let mut take = |name: &str| -> Result<String> {
            it.next().with_context(|| format!("{name} requires a value"))
        };
        match arg.as_str() {
            "-h" | "--help" => {
                print_help();
                return Ok(None);
            }
            "--bundle" => bundle = Some(take("--bundle")?),
            "--css" => css = Some(take("--css")?),
            "--css-file" => css_file = Some(take("--css-file")?),
            "--from" => from = take("--from")?,
            "--polyfills" => {
                polyfills = take("--polyfills")?
                    .parse()
                    .context("--polyfills expects an integer 0..3")?;
            }
            other if other.starts_with('-') && other != "-" => {
                bail!("unknown option: {other}");
            }
            other => classes.push(other.to_string()),
        }
    }

    Ok(Some(Args {
        classes,
        bundle,
        css,
        css_file,
        polyfills,
        from,
    }))
}

fn wasm_path() -> String {
    if let Ok(p) = std::env::var("TW_COMPILER_WASM") {
        return p;
    }
    concat!(env!("CARGO_MANIFEST_DIR"), "/tw-compiler.component.wasm").to_string()
}

fn build_request(args: &Args) -> Result<String> {
    // Entry stylesheet: --css-file wins, then --css, then the default.
    let css = if let Some(path) = &args.css_file {
        std::fs::read_to_string(path).with_context(|| format!("cannot read --css-file {path}"))?
    } else {
        args.css.clone().unwrap_or_else(|| DEFAULT_ENTRY_CSS.to_string())
    };

    // Optional import map (bundle). Must be a JSON object of path -> content.
    let imports: Value = match &args.bundle {
        Some(path) => {
            let text = std::fs::read_to_string(path)
                .with_context(|| format!("cannot read --bundle {path}"))?;
            let value: Value = serde_json::from_str(&text)
                .with_context(|| format!("--bundle {path} is not valid JSON"))?;
            if !value.is_object() {
                bail!("--bundle {path} must be a JSON object of path -> content");
            }
            value
        }
        None => json!({}),
    };

    let request = json!({
        "css": css,
        "candidates": args.classes,
        "imports": imports,
        "base": "",
        "from": args.from,
        "polyfills": args.polyfills,
    });
    Ok(request.to_string())
}

fn main() -> Result<()> {
    let args = match parse_args()? {
        Some(a) => a,
        None => return Ok(()),
    };

    let request = build_request(&args)?;

    // --- instantiate the component and call it ---
    let engine = Engine::default();
    let path = wasm_path();
    let component = Component::from_file(&engine, &path)
        .with_context(|| format!("failed to load component wasm at {path} (run ./build-component.sh?)"))?;
    let linker: Linker<()> = Linker::new(&engine);
    let mut store = Store::new(&engine, ());
    let compiler = Compiler::instantiate(&mut store, &component, &linker)
        .context("failed to instantiate the tw-compiler component")?;

    let response = compiler
        .call_compile_css_json(&mut store, &request)
        .context("compile-css-json trapped")?;

    // Response shape: { "ok": true, "css": "..." } | { "ok": false, "error": "..." }
    let parsed: Value = serde_json::from_str(&response)
        .context("component returned invalid JSON")?;
    if parsed.get("ok").and_then(Value::as_bool) == Some(true) {
        let css = parsed.get("css").and_then(Value::as_str).unwrap_or("");
        print!("{css}");
        if !css.ends_with('\n') {
            println!();
        }
        Ok(())
    } else {
        let err = parsed.get("error").and_then(Value::as_str).unwrap_or("unknown error");
        eprintln!("tailwindcss: {err}");
        std::process::exit(1);
    }
}
