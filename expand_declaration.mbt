///|
/// Expansion of a shorthand declaration into its longhand form.
///
/// This mirrors upstream `expand-declaration.ts`. Tailwind uses it to compare
/// candidates that mean the same thing while spelling it differently, such as
/// `p-4` versus `pt-4 pr-4 pb-4 pl-4`, so it operates on declarations rather
/// than on rendered CSS.

///|
/// Longhand properties of a four-sided shorthand, in `top right bottom left`
/// order.
fn side_expansion(
  prefix : String,
  top : String,
  right : String,
  bottom : String,
  left : String,
) -> Array[String] {
  [
    "\{prefix}-\{top}",
    "\{prefix}-\{right}",
    "\{prefix}-\{bottom}",
    "\{prefix}-\{left}",
  ]
}

///|
fn box_expansion(prefix : String) -> Array[String] {
  side_expansion(prefix, "top", "right", "bottom", "left")
}

///|
/// Map the parts of a shorthand value onto four longhand properties.
fn expand_sides(
  properties : ArrayView[String],
  parts : ArrayView[String],
) -> Array[Declaration]? {
  let picks : Array[Int] = match parts.length() {
    1 => [0, 0, 0, 0]
    2 => [0, 1, 0, 1]
    3 => [0, 1, 2, 1]
    4 => [0, 1, 2, 3]
    _ => return None
  }
  let expanded : Array[Declaration] = []
  for index, property in properties {
    expanded.push(decl(property, parts[picks[index]]))
  }
  Some(expanded)
}

///|
/// Map the parts of a shorthand value onto two longhand properties.
fn expand_pair(
  properties : ArrayView[String],
  parts : ArrayView[String],
) -> Array[Declaration]? {
  let picks : Array[Int] = match parts.length() {
    1 => [0, 0]
    2 => [0, 1]
    _ => return None
  }
  let expanded : Array[Declaration] = []
  for index, property in properties {
    expanded.push(decl(property, parts[picks[index]]))
  }
  Some(expanded)
}

///|
/// Shorthands that always expand, independent of writing direction.
fn physical_shorthand(property : String) -> (Array[String], Bool)? {
  match property {
    "inset" => Some((["top", "right", "bottom", "left"], true))
    "margin" => Some((box_expansion("margin"), true))
    "padding" => Some((box_expansion("padding"), true))
    "scroll-margin" => Some((box_expansion("scroll-margin"), true))
    "scroll-padding" => Some((box_expansion("scroll-padding"), true))
    "border-width" =>
      Some(
        (
          side_expansion(
            "border", "top-width", "right-width", "bottom-width", "left-width",
          ),
          true,
        ),
      )
    "border-style" =>
      Some(
        (
          side_expansion(
            "border", "top-style", "right-style", "bottom-style", "left-style",
          ),
          true,
        ),
      )
    "border-color" =>
      Some(
        (
          side_expansion(
            "border", "top-color", "right-color", "bottom-color", "left-color",
          ),
          true,
        ),
      )
    "gap" => Some((["row-gap", "column-gap"], false))
    "overflow" => Some((["overflow-x", "overflow-y"], false))
    "overscroll-behavior" =>
      Some((["overscroll-behavior-x", "overscroll-behavior-y"], false))
    _ => None
  }
}

///|
/// Logical shorthands that expand only when physical properties are requested.
fn logical_shorthand(property : String) -> Array[String]? {
  match property {
    "inset-block" => Some(["top", "bottom"])
    "inset-inline" => Some(["left", "right"])
    "margin-block" => Some(["margin-top", "margin-bottom"])
    "margin-inline" => Some(["margin-left", "margin-right"])
    "padding-block" => Some(["padding-top", "padding-bottom"])
    "padding-inline" => Some(["padding-left", "padding-right"])
    "scroll-margin-block" => Some(["scroll-margin-top", "scroll-margin-bottom"])
    "scroll-margin-inline" =>
      Some(["scroll-margin-left", "scroll-margin-right"])
    "scroll-padding-block" =>
      Some(["scroll-padding-top", "scroll-padding-bottom"])
    "scroll-padding-inline" =>
      Some(["scroll-padding-left", "scroll-padding-right"])
    _ => None
  }
}

///|
/// Logical border shorthands whose value is copied to each physical property
/// instead of being split.
fn logical_border_shorthand(property : String) -> Array[String]? {
  match property {
    "border-block" => Some(["border-bottom", "border-top"])
    "border-block-color" => Some(["border-bottom-color", "border-top-color"])
    "border-block-style" => Some(["border-bottom-style", "border-top-style"])
    "border-block-width" => Some(["border-bottom-width", "border-top-width"])
    "border-inline" => Some(["border-left", "border-right"])
    "border-inline-color" => Some(["border-left-color", "border-right-color"])
    "border-inline-style" => Some(["border-left-style", "border-right-style"])
    "border-inline-width" => Some(["border-left-width", "border-right-width"])
    _ => None
  }
}

///|
/// Expand a shorthand declaration, or return `None` when it has no expansion.
///
/// `logical_to_physical` enables the direction-dependent expansions, which are
/// only correct when both declarations are known to be laid out left to right.
///
/// Upstream calls this from candidate canonicalization rather than from
/// `compile`, so it is exercised by white-box tests instead of by the public
/// build path.
#warnings("-unused_value")
fn expand_declaration(
  declaration : Declaration,
  logical_to_physical? : Bool = false,
) -> Array[Declaration]? {
  let parts = split_top_level(declaration.value, ' ')
  if logical_to_physical {
    match logical_shorthand(declaration.property) {
      Some(properties) => return expand_pair(properties, parts)
      None => ()
    }
    match logical_border_shorthand(declaration.property) {
      Some(properties) =>
        return Some(
          properties.map(fn(property) { decl(property, declaration.value) }),
        )
      None => ()
    }
  }
  match physical_shorthand(declaration.property) {
    Some((properties, four_sided)) =>
      if four_sided {
        expand_sides(properties, parts)
      } else {
        expand_pair(properties, parts)
      }
    None => None
  }
}
