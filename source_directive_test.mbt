///|
async test "@source exposes file patterns and negation" {
  let compiler = @tailwindcss.compile(
    "@source \"./foo/**/*.ts\"; @source not \"./secret.ts\";",
    options=@tailwindcss.CompileOptions::new(base="/root"),
  )
  json_inspect(compiler.sources(), content=[
    { "base": "/root", "pattern": "./foo/**/*.ts", "negated": false },
    { "base": "/root", "pattern": "./secret.ts", "negated": true },
  ])
}

///|
async test "@source inline includes and excludes candidates" {
  let compiler = @tailwindcss.compile(
    (
      #|@source inline("underline hidden");
      #|@source not inline("hidden");
      #|@tailwind utilities;
      #|
    ),
  )
  inspect(
    compiler.build(["hidden"]),
    content=(
      #|.underline {
      #|  text-decoration-line: underline;
      #|}
      #|
    ),
  )
}
