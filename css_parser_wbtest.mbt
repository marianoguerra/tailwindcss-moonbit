///|
test "CSS parser handles nested rules and declarations" {
  let input =
    #|.foo {
    #|  color: red;
    #|  &:hover { color: blue !important; }
    #|}
    #|
  let ast = parse_css(input)
  inspect(
    render_css_nodes(ast),
    content=(
      #|.foo {
      #|  color: red;
      #|  &:hover {
      #|    color: blue !important;
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "CSS parser preserves balanced values" {
  let ast = parse_css(
    ".foo { color: color-mix(in oklab, red 20%, blue); content: \"a;b\"; }",
  )
  inspect(
    render_css_nodes(ast),
    content=(
      #|.foo {
      #|  color: color-mix(in oklab, red 20%, blue);
      #|  content: "a;b";
      #|}
      #|
    ),
  )
}

///|
test "CSS parser handles at-rules and comments" {
  let ast = parse_css(
    "/*! keep */ @media (width >= 40rem) { .block { display: block; } }",
  )
  inspect(
    render_css_nodes(ast),
    content=(
      #|/*! keep */
      #|@media (width >= 40rem) {
      #|  .block {
      #|    display: block;
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "panic CSS parser rejects unclosed blocks" {
  ignore(parse_css(".foo { color: red;"))
}

///|
test "CSS parser ignores ordinary comments and hoists license comments" {
  let ast = parse_css(
    ".foo/*.removed*/.bar { /* ignored */ color: red; /*! nested */ }\n/*! root */",
  )
  inspect(
    render_css_nodes(ast),
    content=(
      #|/*! nested */
      #|/*! root */
      #|.foo.bar {
      #|  color: red;
      #|}
      #|
    ),
  )
}

///|
test "CSS parser preserves significant whitespace around removed comments" {
  let ast = parse_css(
    ".a/*.x*/.b {}\n.a /*.x*/.b {}\n.a/*.x*/ .b {}\n.a /*.x*/ .b {}",
  )
  inspect(
    render_css_nodes(ast),
    content=(
      #|.a.b {
      #|}
      #|.a .b {
      #|}
      #|.a .b {
      #|}
      #|.a .b {
      #|}
      #|
    ),
  )
}

///|
test "CSS parser accepts BOM repeated semicolons and missing final semicolons" {
  let ast = parse_css("\uFEFF;;; .foo { ;; color: red;;; width: 1px }")
  inspect(
    render_css_nodes(ast),
    content=(
      #|.foo {
      #|  color: red;
      #|  width: 1px;
      #|}
      #|
    ),
  )
}

///|
test "CSS parser preserves permissive custom property values" {
  let cases = [
    ("--empty:;", "--empty", ""),
    ("--space: ;", "--space", ""),
    (
      "--json: {\"a\": [1, 2, {\"b\": \";\"}]};", "--json", "{\"a\": [1, 2, {\"b\": \";\"}]}",
    ),
    (
      "--url: url(data:image/svg+xml;utf8,<svg>{}</svg>);", "--url", "url(data:image/svg+xml;utf8,<svg>{}</svg>)",
    ),
    ("--escaped: foo\\;bar;", "--escaped", "foo\\;bar"),
  ]
  for item in cases {
    let (declaration, expected_name, expected_value) = item
    let ast = parse_css(".foo { \{declaration} }")
    guard ast
      is [Rule(nodes=[Declaration(name~, value~, important=false, ..)], ..)] else {
      fail("expected one custom property declaration")
    }
    inspect(name, content=expected_name)
    inspect(value, content=expected_value)
  }
}

///|
test "CSS parser handles CRLF Unicode and unusual at-rule parameters" {
  let ast = parse_css(
    "@supports selector(:has(> [data-état=\"ouvert\" i])) {\r\n.é > * { content: \"λ;{}\"; }\r\n}",
  )
  inspect(
    render_css_nodes(ast),
    content=(
      #|@supports selector(:has(> [data-état="ouvert" i])) {
      #|  .é > * {
      #|    content: "λ;{}";
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "CSS parser handles escaped selectors and body-less nested at-rules" {
  let ast = parse_css(
    ".foo\\{bar { color: red; }\n@layer utilities { @tailwind utilities }",
  )
  inspect(
    render_css_nodes(ast),
    content=(
      #|.foo\{bar {
      #|  color: red;
      #|}
      #|@layer utilities {
      #|  @tailwind utilities;
      #|}
      #|
    ),
  )
}

///|
test "internal context and at-root nodes render through their children" {
  let span : SourceSpan = { start: 0, end: 0 }
  let declaration = Declaration(
    name="color",
    value="red",
    important=false,
    span~,
  )
  let context_values : Map[String, String] = { "candidate": "block" }
  let ast : Array[CssNode] = [
    Rule(
      selector=".outer",
      nodes=[
        Context(values=context_values, nodes=[declaration], span~),
        AtRoot(
          nodes=[Rule(selector=".root", nodes=[declaration], span~)],
          span~,
        ),
      ],
      span~,
    ),
  ]
  inspect(
    render_css_nodes(ast),
    content=(
      #|.outer {
      #|  color: red;
      #|.root {
      #|  color: red;
      #|}
      #|}
      #|
    ),
  )
}

///|
test "CSS parser rendering is stable across parse-render round trips" {
  let inputs = [
    "a,b { color: red; }", "@media (width >= 40rem) { .foo:hover { display: block; } }",
    ".foo { --payload: {\"nested\": [1, 2]}; content: \"λ\"; }", "/*! keep */ .foo /* remove */ > .bar { color: color-mix(in oklab, red, blue); }",
  ]
  for input in inputs {
    let once = render_css_nodes(parse_css(input))
    let twice = render_css_nodes(parse_css(once))
    inspect(twice, content=once)
  }
}

///|
test "CSS parser rejects malformed syntax" {
  let invalid = [
    "}", ".foo {", ".foo { content: \"unterminated; }", ".foo { color }", ".foo { color: calc(1 + 2; }",
  ]
  for input in invalid {
    try parse_css(input) catch {
      _ => ()
    } noraise {
      _ => fail("expected invalid CSS to be rejected: \{input}")
    }
  }
}
