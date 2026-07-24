///|
test "candidate parser separates variants, negative forms, modifiers, and important" {
  guard parse_candidate("md:hover:-bg-brand/50!") is Some(candidate) else {
    fail("expected a candidate")
  }
  assert_eq(candidate.base(), "bg-brand")
  assert_true(candidate.negative)
  assert_true(candidate.important)
  assert_eq(candidate.modifier_source(), Some("50"))
  assert_eq(candidate.variants.map(fn(variant) { variant.source() }), [
    "md", "hover",
  ])
}

///|
test "candidate parser does not split slashes inside arbitrary values" {
  guard parse_candidate("bg-[url(https://example.com/a.png)]")
    is Some(candidate) else {
    fail("expected a candidate")
  }
  assert_eq(candidate.base(), "bg-[url(https://example.com/a.png)]")
  assert_false(candidate.negative)
  assert_false(candidate.important)
  assert_eq(candidate.modifier_source(), None)
  assert_true(candidate.variants.is_empty())
}

///|
test "candidate parser rejects empty candidates and modifiers" {
  assert_true(parse_candidate("") is None)
  assert_true(parse_candidate("bg-red/") is None)
}

///|
test "arbitrary value decoding matches Tailwind underscore rules" {
  let cases = [
    ("hello_world", "hello world"),
    ("hello\\_world", "hello_world"),
    ("url(https://example.com/a_b.png)", "url(https://example.com/a_b.png)"),
    ("var(--my_variable)", "var(--my_variable)"),
    ("var(--my_variable,_fallback_value)", "var(--my_variable, fallback value)"),
    ("theme(--my_theme,_fallback)", "theme(--my_theme, fallback)"),
    ("foo_bar(baz_qux)", "foo bar(baz qux)"),
    ("calc(var(--_foo)*0.2)", "calc(var(--_foo) * 0.2)"),
    ("calc(0.2*var(--\\_foo))", "calc(0.2 * var(--_foo))"),
    ("calc(100%-1rem)", "calc(100% - 1rem)"),
    ("calc(-3.4e-2*1px)", "calc(-3.4e-2 * 1px)"),
    ("min(1px,2px)", "min(1px, 2px)"),
    ("min(-1px,calc(-2px+3px))", "min(-1px, calc(-2px + 3px))"),
  ]
  for item in cases {
    let (input, expected) = item
    inspect(decode_arbitrary(input), content=expected)
  }
}

///|
test "arbitrary value validation rejects imbalance and top-level injection" {
  let valid = [
    "red", "var(--x)", "calc(1;2)", "\"a;{}\"", "url(data:image/svg+xml;foo)",
  ]
  let invalid = [
    "red;display:block", "foo}", "foo)", "foo]", "calc(1]", "(foo", "[foo",
  ]
  for value in valid {
    assert_true(is_valid_arbitrary(value))
  }
  for value in invalid {
    assert_false(is_valid_arbitrary(value))
  }
}

///|
test "candidate parser never panics on arbitrary candidate corpus" {
  let corpus = [
    "[]", "[:]", "[color:]", "[:red]", "[color:red;display:block]", "bg-[]", "bg-[var(--x)]",
    "bg-(--token)", "group-[&:focus]/name:flex", "[&{color:red}]:flex", "α:[color:λ]",
    "\\",
  ]
  for raw in corpus {
    ignore(parse_candidate(raw))
  }
}

///|
test "candidate printing canonicalizes legacy important syntax and round-trips" {
  let candidates = [
    "hover:flex!", "-m-2", "bg-[#0088cc]/[50%]", "[mask-type:luminance]", "group-[&:focus]/form:flex",
  ]
  for raw in candidates {
    guard parse_candidate(raw) is Some(candidate) else {
      fail("expected valid candidate: \{raw}")
    }
    let printed = print_candidate(candidate)
    guard parse_candidate(printed) is Some(reparsed) else {
      fail("printed candidate should parse: \{printed}")
    }
    inspect(print_candidate(reparsed), content=printed)
  }
  guard parse_candidate("!flex") is Some(legacy) else {
    fail("legacy important syntax should parse")
  }
  inspect(print_candidate(legacy), content="flex!")
}

///|
test "candidate parser rejects invalid arbitrary forms at parse time" {
  let invalid = [
    "bg-red/50/25", "[Color:red]", "[color:]", "[:red]", "[color:red;display:block]",
    "-[color:red]", "bg-[]", "bg-()", "bg-(token)", "[]:flex", "hover::flex",
  ]
  for raw in invalid {
    assert_true(parse_candidate(raw) is None)
  }
}

///|
test "candidate parser uses explicit semantic forms" {
  guard parse_candidate("flex")
    is Some({ form: StaticCandidate(root="flex"), .. }) else {
    fail("expected a static candidate")
  }
  guard parse_candidate("bg-red-500/50")
    is Some(
      {
        form: FunctionalCandidate(
          value=Some(NamedValue(value="500", fraction=Some("500/50"))),
          ..
        ),
        modifier: Some(NamedModifier(value="50", ..)),
        ..,
      }
    ) else {
    fail("expected a named functional candidate")
  }
  guard parse_candidate("bg-[color:var(--paint)]/[50%]")
    is Some(
      {
        form: FunctionalCandidate(
          root="bg",
          value=Some(
            ArbitraryValue(data_type=Some("color"), value="var(--paint)")
          ),
          ..
        ),
        modifier: Some(ArbitraryModifier(value="50%", ..)),
        ..,
      }
    ) else {
    fail("expected an arbitrary functional candidate")
  }
  guard parse_candidate("[mask-type:luminance]")
    is Some(
      {
        form: ArbitraryPropertyCandidate(
          property="mask-type",
          value="luminance",
          ..
        ),
        ..,
      }
    ) else {
    fail("expected an arbitrary property candidate")
  }
  guard parse_candidate("group-[&:focus]/form:flex")
    is Some(
      {
        variants: [
          CompoundVariant(
            root="group",
            modifier=Some(NamedModifier(value="form", ..)),
            variant=ArbitraryVariant(relative=false, ..),
            ..
          ),
        ],
        ..,
      }
    ) else {
    fail("expected a nested compound variant")
  }
}

///|
test "candidate canonicalization normalizes arbitrary selectors and forwarded modifiers" {
  let cases = [
    ("[_p_]:flex", "[p]:flex"),
    ("[&:is(_p_)]:flex", "[p]:flex"),
    ("has-[&:is(p)]:flex", "has-[p]:flex"),
    ("not-group-hover/name:flex", "not-group-hover/name:flex"),
    ("has-group-peer-hover/name:flex", "has-group-peer-hover/name:flex"),
    ("group-peer-focus/name:flex", "group-peer-focus/name:flex"),
  ]
  for item in cases {
    let (input, expected) = item
    guard parse_candidate(input) is Some(candidate) else {
      fail("expected valid candidate: \{input}")
    }
    inspect(print_candidate(candidate), content=expected)
  }
  guard parse_candidate("not-group-hover/name:flex")
    is Some(
      {
        variants: [
          CompoundVariant(
            root="not",
            modifier=None,
            variant=CompoundVariant(
              root="group",
              modifier=Some(NamedModifier(value="name", ..)),
              ..
            ),
            ..
          ),
        ],
        ..,
      }
    ) else {
    fail("modifier should move from not to its nested group")
  }
}
