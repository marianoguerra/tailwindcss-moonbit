///|
test "attribute selector parser rejects malformed selectors" {
  let invalid = [
    "", "]", "[]", "[", "=\"value\"", "data-foo]", "[data-foo", "[data-foo=\"foo]",
    "[data-foo * = foo]", "[data-foo*=]", "[data-foo=value x]", "[data-foo=value ix]",
  ]
  for selector in invalid {
    assert_true(parse_attribute_selector(selector) is None)
  }
}

///|
test "attribute selector parser accepts upstream forms" {
  guard parse_attribute_selector("[data-foo]")
    is Some({ attribute: "data-foo", operator: None, .. }) else {
    fail("expected a presence selector")
  }
  guard parse_attribute_selector("[ data-état ]")
    is Some({ attribute: "data-état", operator: None, .. }) else {
    fail("expected a non-ASCII attribute name")
  }
  guard parse_attribute_selector("[data-state = expanded ]")
    is Some(
      {
        attribute: "data-state",
        operator: Some("="),
        quote: None,
        value: Some("expanded"),
        sensitivity: None,
      }
    ) else {
    fail("expected an unquoted attribute value")
  }
  guard parse_attribute_selector("[data-url$=\".com\"i]")
    is Some(
      {
        attribute: "data-url",
        operator: Some("$="),
        quote: Some("\""),
        value: Some(".com"),
        sensitivity: Some("i"),
      }
    ) else {
    fail("expected a quoted, case-insensitive attribute value")
  }
}
