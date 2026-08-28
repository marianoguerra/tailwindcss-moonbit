///|
/// The sides a `mask-<edge>-*` utility drives, in the order upstream emits them.
let mask_edges : Array[(String, Array[String])] = [
  ("mask-t", ["top"]),
  ("mask-r", ["right"]),
  ("mask-b", ["bottom"]),
  ("mask-l", ["left"]),
  ("mask-x", ["right", "left"]),
  ("mask-y", ["top", "bottom"]),
]

///|
/// The plumbing every mask utility re-declares, so that several of them
/// combine: the image is composed from the three gradient slots, and the linear
/// slot from the four sides.
fn mask_composition_declarations() -> Array[Declaration] {
  [
    decl(
      "mask-image", "var(--tw-mask-linear), var(--tw-mask-radial), var(--tw-mask-conic)",
    ),
    decl("mask-composite", "intersect"),
    decl(
      "--tw-mask-linear", "var(--tw-mask-left), var(--tw-mask-right), var(--tw-mask-bottom), var(--tw-mask-top)",
    ),
  ]
}

///|
/// A mask stop is a position or a color, the same split the gradient stops
/// make — but a bare number here is a spacing multiplier, and an untyped
/// arbitrary value is a color unless it reads as a measurement.
fn mask_stop_value(
  theme : Map[String, String],
  key : String,
) -> (String, Bool)? {
  // A percentage stop is a whole number here, unlike the gradient stops.
  if key.has_suffix("%") {
    let number = key[:key.length() - 1].to_owned()
    return if is_nonnegative_integer(number) { Some((key, true)) } else { None }
  }
  match arbitrary_typed_value(key) {
    Some((value, Some("color"))) => return Some((value, false))
    Some((value, Some(_))) => return Some((value, true))
    // Without a typehint a mask stop is a position: upstream lists the length
    // types before the color one, and a bare `var()` infers nothing. A negative
    // measurement is not a position at all.
    Some((value, None)) =>
      return if value.has_prefix("-") && is_number_with_unit(value) {
        None
      } else {
        Some((value, true))
      }
    None => ()
  }
  match keyword_color(key) {
    Some(value) => return Some((value, false))
    None => ()
  }
  match theme_css_value(theme, "--color-\{key}") {
    Some(value) => return Some((value, false))
    None => ()
  }
  numeric_spacing(theme, key).map(fn(value) { (value, true) })
}

///|
/// `mask-t-from-50%` and friends: a linear gradient masking one edge, or two
/// for the `x` and `y` forms. The value is a stop, read the same way a gradient
/// stop is — a position or a color.
fn mask_edge_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  guard name.has_prefix("mask-") else { return None }
  for entry in mask_edges {
    let (root, sides) = entry
    for stop in ["from", "to"] {
      let prefix = "\{root}-\{stop}"
      guard prefixed_value(name, prefix) is Some(key) else { continue }
      guard mask_stop_value(theme, key) is Some((value, position)) else {
        return None
      }
      let declarations = mask_composition_declarations()
      for side in sides {
        declarations.push(
          decl(
            "--tw-mask-\{side}",
            "linear-gradient(to \{side}, var(--tw-mask-\{side}-from-color) var(--tw-mask-\{side}-from-position), var(--tw-mask-\{side}-to-color) var(--tw-mask-\{side}-to-position))",
          ),
        )
        let slot = if position { "position" } else { "color" }
        declarations.push(decl("--tw-mask-\{side}-\{stop}-\{slot}", value))
      }
      return Some(declarations)
    }
  }
  None
}
