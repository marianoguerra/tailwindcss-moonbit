///|
test "selector parser round-trips and normalizes combinators" {
  inspect(
    render_selector(parse_selector(".foo>.bar + [data-x=\"a>b\"]")),
    content=".foo > .bar + [data-x=\"a>b\"]",
  )
  inspect(
    render_selector(parse_selector(":is(.foo,.bar > *)")),
    content=":is(.foo, .bar > *)",
  )
}

///|
test "selector nesting replacement traverses pseudo functions only" {
  inspect(
    rewrite_arbitrary_selector(":is(&>*,[data-value=\"&\"])", ".candidate"),
    content=":is(.candidate > *, [data-value=\"&\"])",
  )
  inspect(
    rewrite_arbitrary_selector("[data-theme=dark]", ".candidate"),
    content="[data-theme=dark] .candidate",
  )
}

///|
test "selector parser covers upstream selector forms" {
  let selectors = [
    ".foo.bar:hover#id", ".foo::before", ".foo, .bar", "[foo], [bar]", ".a + .b, .c .d[attr], .e",
    ".foo[bar=\"baz\"]", ".foo:hover:not(.bar:focus)", "foo\\.bar", ":nth-child(n+1)",
    ":nth-child(2n + 1 of .foo,.bar)", "&[data-foo]", "[data-foo]&", "*|* > svg|a[href]",
    ":has(> .child, + .sibling)",
  ]
  let expected = [
    ".foo.bar:hover#id", ".foo::before", ".foo, .bar", "[foo], [bar]", ".a + .b, .c .d[attr], .e",
    ".foo[bar=\"baz\"]", ".foo:hover:not(.bar:focus)", "foo\\.bar", ":nth-child(n+1)",
    ":nth-child(2n + 1 of .foo, .bar)", "&[data-foo]", "[data-foo]&", "*|* > svg|a[href]",
    ":has( > .child,  + .sibling)",
  ]
  for index, selector in selectors {
    inspect(render_selector(parse_selector(selector)), content=expected[index])
  }
  inspect(
    render_selector(parse_selector(".a+.b, .c .d[attr], .e"), minify=true),
    content=".a+.b,.c .d[attr],.e",
  )
}

///|
test "selector parser preserves invalid lists and never panics" {
  let selectors = [
    ".foo,", ",.foo", ",.foo,", ".foo,,.bar", "[", "(", "\\", ":is(,)",
  ]
  for selector in selectors {
    ignore(render_selector(parse_selector(selector)))
  }
}
