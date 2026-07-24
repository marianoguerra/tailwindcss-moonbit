///|
test "value parser round-trips nested functions, strings, and separators" {
  let values = [
    "123px", "'hello ( world )'", "theme(foo, theme(bar))", "theme(colors.red.500/var(--opacity))",
    "calc((1 + 2) * 3)", "(width>=theme(--breakpoint-sm))",
  ]
  for value in values {
    inspect(render_value(parse_value(value)), content=value)
  }
}

///|
test "value parser exposes function and separator structure" {
  match parse_value("theme(foo, bar)") {
    [
      ValueFunction(
        "theme",
        [ValueWord("foo"), ValueSeparator(", "), ValueWord("bar")]
      ),
    ] => ()
    other => fail("unexpected value AST: \{to_repr(other)}")
  }
}

///|
test "value parser matches upstream edge cases" {
  let values = [
    "theme()", "theme(\n\tfoo,\n\tbar\n)", "theme(colors.red.500/var(--opacity))",
    "calc((1 + 2) * 3)", "(min-width: 600px) and (max-width:theme(colors.red.500))",
    "foo(   bar  )",
  ]
  for value in values {
    inspect(render_value(parse_value(value)), content=value)
  }
  inspect(render_value(parse_value("calc(1 + 2))")), content="calc(1 + 2)")
}

///|
test "value parser never panics on malformed or escaped input" {
  let values = [
    "", ")", "(((", "\\", "\"unterminated", "var(--x, calc(1 + (2)))", "α(β, γ)",
  ]
  for value in values {
    ignore(parse_value(value))
  }
}
