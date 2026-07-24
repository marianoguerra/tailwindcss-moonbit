///|
test "folds constant calc expressions" {
  assert_eq(
    canonicalize_calc_expressions("calc(1px + 2px)", convert_units=false),
    "3px",
  )
  assert_eq(
    canonicalize_calc_expressions("calc(5px - 2px)", convert_units=false),
    "3px",
  )
  assert_eq(
    canonicalize_calc_expressions("calc(2 * 3px)", convert_units=false),
    "6px",
  )
  assert_eq(
    canonicalize_calc_expressions("calc(3px * 2)", convert_units=false),
    "6px",
  )
  assert_eq(
    canonicalize_calc_expressions("calc(10px / 4)", convert_units=false),
    "2.5px",
  )
}

///|
test "keeps calc expressions it cannot fold" {
  assert_eq(
    canonicalize_calc_expressions("calc(100% - 1px)", convert_units=false),
    "calc(100% - 1px)",
  )
  assert_eq(
    canonicalize_calc_expressions("calc(1px / 3)", convert_units=false),
    "calc(1px / 3)",
  )
  assert_eq(
    canonicalize_calc_expressions("calc(1px / 0)", convert_units=false),
    "calc(1px / 0)",
  )
  assert_eq(
    canonicalize_calc_expressions("calc(2px * 3em)", convert_units=false),
    "calc(2px * 3em)",
  )
  assert_eq(
    canonicalize_calc_expressions("calc(var(--x) + 1px)", convert_units=false),
    "calc(var(--x) + 1px)",
  )
}

///|
test "collapses identity and zero factors" {
  assert_eq(
    canonicalize_calc_expressions("calc(0 * 5px)", convert_units=false),
    "0",
  )
  assert_eq(
    canonicalize_calc_expressions("calc(1 * 5px)", convert_units=false),
    "5px",
  )
  assert_eq(
    canonicalize_calc_expressions("calc(5px * 1)", convert_units=false),
    "5px",
  )
}

///|
test "canonicalizes absolute units" {
  assert_eq(canonicalize_unit("1in"), Some("96px"))
  assert_eq(canonicalize_unit("2.54cm"), Some("96px"))
  assert_eq(canonicalize_unit("1mm"), Some("3.7795275590551176px"))
  assert_eq(canonicalize_unit("1q"), Some("0.9448818897637794px"))
  assert_eq(canonicalize_unit("1pc"), Some("16px"))
  assert_eq(canonicalize_unit("72pt"), Some("96px"))
  assert_eq(canonicalize_unit("1turn"), Some("360deg"))
  assert_eq(canonicalize_unit("400grad"), Some("360deg"))
  assert_eq(canonicalize_unit("500ms"), Some("0.5s"))
  assert_eq(canonicalize_unit("2khz"), Some("2000hz"))
  assert_eq(canonicalize_unit("3px"), Some("3px"))
  assert_eq(canonicalize_unit("50%"), Some("50%"))
  assert_eq(canonicalize_unit("auto"), None)
}

///|
test "rem conversion needs a root font size" {
  assert_eq(canonicalize_unit("2rem"), None)
  assert_eq(canonicalize_unit("2rem", rem=16.0), Some("32px"))
}

///|
test "canonicalization folds converted units together" {
  assert_eq(canonicalize_calc_expressions("calc(1in + 2px)"), "98px")
  assert_eq(
    canonicalize_calc_expressions("calc(2rem + 2px)"),
    "calc(2rem + 2px)",
  )
  assert_eq(canonicalize_calc_expressions("calc(2rem + 2px)", rem=16.0), "34px")
}
