///|
fn expanded_pairs(
  declaration : Declaration,
  logical_to_physical? : Bool = false,
) -> Array[(String, String)]? {
  expand_declaration(declaration, logical_to_physical~).map(fn(declarations) {
    declarations.map(fn(entry) { (entry.property, entry.value) })
  })
}

///|
test "expands four sided shorthands by part count" {
  assert_eq(
    expanded_pairs(decl("margin", "1px")),
    Some([
      ("margin-top", "1px"),
      ("margin-right", "1px"),
      ("margin-bottom", "1px"),
      ("margin-left", "1px"),
    ]),
  )
  assert_eq(
    expanded_pairs(decl("padding", "1px 2px")),
    Some([
      ("padding-top", "1px"),
      ("padding-right", "2px"),
      ("padding-bottom", "1px"),
      ("padding-left", "2px"),
    ]),
  )
  assert_eq(
    expanded_pairs(decl("inset", "1px 2px 3px")),
    Some([("top", "1px"), ("right", "2px"), ("bottom", "3px"), ("left", "2px")]),
  )
  assert_eq(
    expanded_pairs(decl("scroll-margin", "1px 2px 3px 4px")),
    Some([
      ("scroll-margin-top", "1px"),
      ("scroll-margin-right", "2px"),
      ("scroll-margin-bottom", "3px"),
      ("scroll-margin-left", "4px"),
    ]),
  )
}

///|
test "expands border shorthands" {
  assert_eq(
    expanded_pairs(decl("border-width", "1px 2px")),
    Some([
      ("border-top-width", "1px"),
      ("border-right-width", "2px"),
      ("border-bottom-width", "1px"),
      ("border-left-width", "2px"),
    ]),
  )
  assert_eq(
    expanded_pairs(decl("border-style", "solid")),
    Some([
      ("border-top-style", "solid"),
      ("border-right-style", "solid"),
      ("border-bottom-style", "solid"),
      ("border-left-style", "solid"),
    ]),
  )
}

///|
test "expands paired shorthands" {
  assert_eq(
    expanded_pairs(decl("gap", "1px 2px")),
    Some([("row-gap", "1px"), ("column-gap", "2px")]),
  )
  assert_eq(
    expanded_pairs(decl("overflow", "hidden")),
    Some([("overflow-x", "hidden"), ("overflow-y", "hidden")]),
  )
  assert_eq(
    expanded_pairs(decl("overscroll-behavior", "auto contain")),
    Some([
      ("overscroll-behavior-x", "auto"),
      ("overscroll-behavior-y", "contain"),
    ]),
  )
}

///|
test "keeps values with nested separators intact" {
  assert_eq(
    expanded_pairs(decl("margin", "calc(1px + 2px) 3px")),
    Some([
      ("margin-top", "calc(1px + 2px)"),
      ("margin-right", "3px"),
      ("margin-bottom", "calc(1px + 2px)"),
      ("margin-left", "3px"),
    ]),
  )
}

///|
test "rejects values with the wrong part count" {
  assert_eq(expanded_pairs(decl("margin", "1px 2px 3px 4px 5px")), None)
  assert_eq(expanded_pairs(decl("gap", "1px 2px 3px")), None)
  assert_eq(expanded_pairs(decl("color", "red")), None)
}

///|
test "expands logical shorthands only when requested" {
  assert_eq(expanded_pairs(decl("margin-inline", "1px 2px")), None)
  assert_eq(
    expanded_pairs(decl("margin-inline", "1px 2px"), logical_to_physical=true),
    Some([("margin-left", "1px"), ("margin-right", "2px")]),
  )
  assert_eq(
    expanded_pairs(decl("inset-block", "1px"), logical_to_physical=true),
    Some([("top", "1px"), ("bottom", "1px")]),
  )
  assert_eq(
    expanded_pairs(decl("border-inline-width", "2px"), logical_to_physical=true),
    Some([("border-left-width", "2px"), ("border-right-width", "2px")]),
  )
  assert_eq(
    expanded_pairs(
      decl("border-block", "1px solid red"),
      logical_to_physical=true,
    ),
    Some([("border-bottom", "1px solid red"), ("border-top", "1px solid red")]),
  )
}

///|
test "splits only at the top level" {
  assert_eq(split_top_level("a b c", ' '), ["a", "b", "c"])
  assert_eq(split_top_level("rgb(1, 2, 3) red", ' '), ["rgb(1, 2, 3)", "red"])
  assert_eq(split_top_level("var(--a, b c) d", ' '), ["var(--a, b c)", "d"])
  assert_eq(split_top_level("\"a b\" c", ' '), ["\"a b\"", "c"])
  assert_eq(split_top_level("[a b] c", ' '), ["[a b]", "c"])
  assert_eq(split_top_level("solid", ' '), ["solid"])
}

///|
test "finds substring positions" {
  assert_eq(index_of("abcabc", "c"), Some(2))
  assert_eq(index_of("abc", "abc"), Some(0))
  assert_eq(index_of("abc", "d"), None)
  assert_eq(index_of("abc", "abcd"), None)
}
