///|
priv struct Declaration {
  property : String
  value : String
  fallback : String?
}

///|
fn decl(property : String, value : String) -> Declaration {
  { property, value, fallback: None }
}

///|
/// Upstream's `asColor`: an arbitrary modifier is taken as written, a bare one
/// must name an `--opacity-*` theme key or be a valid opacity value. Anything
/// else means the candidate does not exist, hence the `None`.
fn alpha_modifier_value(
  theme : Map[String, String],
  modifier : String,
) -> String? {
  match arbitrary_value(modifier) {
    Some(value) => Some(value)
    None =>
      match theme_css_value(theme, "--opacity-\{modifier}") {
        Some(value) => Some(value)
        None => if is_spacing_number(modifier) { Some("\{modifier}%") } else { None }
      }
  }
}

///|
/// Upstream's `withAlpha`: a numeric alpha becomes a percentage so `color-mix`
/// accepts it, and a fully opaque color needs no mix at all.
fn apply_alpha(value : String, alpha : String) -> String {
  let parsed = @string.parse_double(alpha) catch { _ => @double.not_a_number }
  let alpha = if parsed.is_nan() {
    alpha
  } else {
    "\{parsed * 100.0}%"
  }
  if alpha == "100%" {
    return value
  }
  "color-mix(in oklab, \{value} \{alpha}, transparent)"
}

///|
fn theme_literal_for_value(
  theme : Map[String, String],
  value : String,
) -> String? {
  for name, literal in theme {
    if !name.has_prefix(theme_meta_prefix) &&
      theme_css_value(theme, name) == Some(value) {
      return Some(literal)
    }
  }
  None
}

///|
fn negate_value(value : String) -> String {
  // A transform function negates its angle, not itself: upstream writes
  // `rotateX(calc(45deg * -1))`, never `calc(rotateX(45deg) * -1)`.
  for function_name in ["rotateX", "rotateY", "rotateZ", "skewX", "skewY"] {
    let opening = "\{function_name}("
    if value.has_prefix(opening) && value.has_suffix(")") {
      let inner = value[opening.length():value.length() - 1].to_owned()
      return "\{function_name}(calc(\{inner} * -1))"
    }
  }
  let spacing_prefix = "calc(var(--spacing) * "
  if value.has_prefix(spacing_prefix) && value.has_suffix(")") {
    let factor = value[spacing_prefix.length():value.length() - 1].to_owned()
    "calc(var(--spacing) * -\{factor})"
  } else if value == "100%" {
    "-100%"
  } else if value == "1px" {
    // The `-px` spacing static is registered as `-1px` upstream, not as a calc.
    "-1px"
  } else if value == "var(--spacing)" {
    "calc(var(--spacing) * -1)"
  } else {
    "calc(\{value} * -1)"
  }
}

///|
/// `None` when the candidate carries an alpha modifier the colors cannot take —
/// upstream's `asColor` returns null there, and a null value means no rule.
fn apply_candidate_value(
  theme : Map[String, String],
  declarations : Array[Declaration],
  negative : Bool,
  modifier : String?,
) -> Array[Declaration]? {
  let wants_alpha = declarations
    .iter()
    .any(fn(declaration) { is_alpha_property(declaration.property) })
  let modifier = if wants_alpha {
    match modifier {
      Some(source) =>
        match alpha_modifier_value(theme, source) {
          Some(alpha) => Some(alpha)
          None => return None
        }
      None => None
    }
  } else {
    modifier
  }
  Some(declarations.map(fn(declaration) {
    let (value, fallback) = match modifier {
      Some(alpha) =>
        if is_alpha_property(declaration.property) {
          let advanced = apply_alpha(declaration.value, alpha)
          let fallback = theme_literal_for_value(theme, declaration.value).map(fn(
            literal,
          ) {
            replace_all(
              advanced,
              "in oklab, \{declaration.value}",
              "in srgb, \{literal}",
            )
          })
          (advanced, fallback)
        } else {
          (declaration.value, None)
        }
      None => (declaration.value, declaration.fallback)
    }
    {
      property: declaration.property,
      value: if negative && !declaration.value.contains("var(--tw-") {
        negate_value(value)
      } else {
        value
      },
      fallback,
    }
  }))
}

///|
fn numeric_spacing(theme : Map[String, String], value : String) -> String? {
  // Upstream's `spacingUtility` registers exactly one static value, `-px`; a
  // utility that also takes `auto` or `full` declares that for itself.
  if value == "px" {
    return Some("1px")
  }
  guard is_spacing_number(value) else { return None }
  guard theme_css_value(theme, "--spacing") is Some(base) else { return None }
  if value == "1" {
    Some(base)
  } else {
    Some("calc(\{base} * \{value})")
  }
}

///|
/// An arbitrary value with the data type it names, if any.
///
/// `[color:var(--x)]` is a value with a `color` typehint; `[url(http://…)]` is
/// a value with a colon in it. Upstream tells them apart syntactically: a
/// typehint runs up to the first `:` and is made only of lowercase letters and
/// dashes, so `url(http` — with its `(` — is not one.
fn arbitrary_typed_value(value : String) -> (String, String?)? {
  guard value.has_prefix("[") && value.has_suffix("]") && value.length() >= 2 else {
    return None
  }
  let inner = decode_arbitrary(value[1:value.length() - 1].to_owned())
  let mut index = 0
  while index < inner.length() &&
        ((inner[index] >= 'a' && inner[index] <= 'z') || inner[index] == '-') {
    index += 1
  }
  if index > 0 && index < inner.length() && inner[index] == ':' {
    return Some((inner[index + 1:].to_owned(), Some(inner[:index].to_owned())))
  }
  Some((inner, None))
}

///|
/// The two ways a candidate can carry a value of its own: `[…]` for an
/// arbitrary value and `(--x)` for the custom-property shorthand, which stands
/// for `var(--x)` and may name a data type as `(<type>:--x)`. Underscores are
/// decoded only in the bracket form — a custom property name keeps its own.
fn arbitrary_value(value : String) -> String? {
  match arbitrary_typed_value(value) {
    Some((value, _)) => return Some(value)
    None => ()
  }
  guard value.length() >= 5 && value.has_prefix("(") && value.has_suffix(")") else {
    return None
  }
  let inner = value[1:value.length() - 1].to_owned()
  if inner.has_prefix("--") {
    return Some("var(\{inner})")
  }
  match inner.split_once(":") {
    Some((_, variable)) if variable.has_prefix("--") =>
      Some("var(\{variable.to_owned()})")
    _ => None
  }
}

///|
fn resolved_value(
  theme : Map[String, String],
  value : String,
  theme_namespace : String,
  spacing : Bool,
) -> String? {
  match arbitrary_value(value) {
    Some(v) => Some(v)
    None =>
      match theme_value(theme, theme_namespace, value) {
        Some(_) => theme_css_value(theme, "\{theme_namespace}-\{value}")
        None if spacing && theme_value(theme, "--spacing", value) is Some(_) =>
          // Upstream's spacing utilities resolve against two namespaces — their
          // own and `--spacing` — so `mt-4` finds a `--spacing-4` theme key
          // before it falls back to the `--spacing` multiplier.
          theme_css_value(theme, "--spacing-\{value}")
        None =>
          match value.split_once("/") {
            Some((numerator, denominator)) if is_nonnegative_integer(
                numerator.to_owned(),
              ) &&
              is_nonnegative_integer(denominator.to_owned()) &&
              denominator != "0" =>
              Some("calc(\{numerator} / \{denominator} * 100%)")
            _ => if spacing { numeric_spacing(theme, value) } else { None }
          }
      }
  }
}

///|
fn static_utility(name : String) -> Array[Declaration]? {
  match name {
    "sr-only" =>
      Some([
        decl("position", "absolute"),
        decl("width", "1px"),
        decl("height", "1px"),
        decl("padding", "0"),
        decl("margin", "-1px"),
        decl("overflow", "hidden"),
        decl("clip-path", "inset(50%)"),
        decl("white-space", "nowrap"),
        decl("border-width", "0"),
      ])
    "not-sr-only" =>
      Some([
        decl("position", "static"),
        decl("width", "auto"),
        decl("height", "auto"),
        decl("padding", "0"),
        decl("margin", "0"),
        decl("overflow", "visible"),
        decl("clip-path", "none"),
        decl("white-space", "normal"),
      ])
    "pointer-events-none" => Some([decl("pointer-events", "none")])
    "pointer-events-auto" => Some([decl("pointer-events", "auto")])
    "block" => Some([decl("display", "block")])
    "inline-block" => Some([decl("display", "inline-block")])
    "inline" => Some([decl("display", "inline")])
    "flex" => Some([decl("display", "flex")])
    "inline-flex" => Some([decl("display", "inline-flex")])
    "grid" => Some([decl("display", "grid")])
    "inline-grid" => Some([decl("display", "inline-grid")])
    "hidden" => Some([decl("display", "none")])
    "contents" => Some([decl("display", "contents")])
    "flow-root" => Some([decl("display", "flow-root")])
    "table" => Some([decl("display", "table")])
    "inline-table" => Some([decl("display", "inline-table")])
    "table-caption" => Some([decl("display", "table-caption")])
    "table-cell" => Some([decl("display", "table-cell")])
    "table-column" => Some([decl("display", "table-column")])
    "table-column-group" => Some([decl("display", "table-column-group")])
    "table-footer-group" => Some([decl("display", "table-footer-group")])
    "table-header-group" => Some([decl("display", "table-header-group")])
    "table-row-group" => Some([decl("display", "table-row-group")])
    "table-row" => Some([decl("display", "table-row")])
    "list-item" => Some([decl("display", "list-item")])
    "field-sizing-content" => Some([decl("field-sizing", "content")])
    "field-sizing-fixed" => Some([decl("field-sizing", "fixed")])
    "grid-flow-row" => Some([decl("grid-auto-flow", "row")])
    "grid-flow-col" => Some([decl("grid-auto-flow", "column")])
    "grid-flow-dense" => Some([decl("grid-auto-flow", "dense")])
    "grid-flow-row-dense" => Some([decl("grid-auto-flow", "row dense")])
    "grid-flow-col-dense" => Some([decl("grid-auto-flow", "column dense")])
    "auto-cols-auto" => Some([decl("grid-auto-columns", "auto")])
    "auto-cols-min" => Some([decl("grid-auto-columns", "min-content")])
    "auto-cols-max" => Some([decl("grid-auto-columns", "max-content")])
    "auto-cols-fr" => Some([decl("grid-auto-columns", "minmax(0, 1fr)")])
    "auto-rows-auto" => Some([decl("grid-auto-rows", "auto")])
    "auto-rows-min" => Some([decl("grid-auto-rows", "min-content")])
    "auto-rows-max" => Some([decl("grid-auto-rows", "max-content")])
    "auto-rows-fr" => Some([decl("grid-auto-rows", "minmax(0, 1fr)")])
    "grid-cols-none" => Some([decl("grid-template-columns", "none")])
    "grid-cols-subgrid" => Some([decl("grid-template-columns", "subgrid")])
    "grid-rows-none" => Some([decl("grid-template-rows", "none")])
    "grid-rows-subgrid" => Some([decl("grid-template-rows", "subgrid")])
    "col-auto" => Some([decl("grid-column", "auto")])
    "col-span-full" => Some([decl("grid-column", "1 / -1")])
    "col-start-auto" => Some([decl("grid-column-start", "auto")])
    "col-end-auto" => Some([decl("grid-column-end", "auto")])
    "row-auto" => Some([decl("grid-row", "auto")])
    "row-span-full" => Some([decl("grid-row", "1 / -1")])
    "row-start-auto" => Some([decl("grid-row-start", "auto")])
    "row-end-auto" => Some([decl("grid-row-end", "auto")])
    "static" => Some([decl("position", "static")])
    "fixed" => Some([decl("position", "fixed")])
    "absolute" => Some([decl("position", "absolute")])
    "relative" => Some([decl("position", "relative")])
    "sticky" => Some([decl("position", "sticky")])
    "visible" => Some([decl("visibility", "visible")])
    "invisible" => Some([decl("visibility", "hidden")])
    "collapse" => Some([decl("visibility", "collapse")])
    "overflow-auto" => Some([decl("overflow", "auto")])
    "overflow-hidden" => Some([decl("overflow", "hidden")])
    "overflow-clip" => Some([decl("overflow", "clip")])
    "overflow-visible" => Some([decl("overflow", "visible")])
    "overflow-scroll" => Some([decl("overflow", "scroll")])
    "overflow-x-auto" => Some([decl("overflow-x", "auto")])
    "overflow-x-hidden" => Some([decl("overflow-x", "hidden")])
    "overflow-x-clip" => Some([decl("overflow-x", "clip")])
    "overflow-x-visible" => Some([decl("overflow-x", "visible")])
    "overflow-x-scroll" => Some([decl("overflow-x", "scroll")])
    "overflow-y-auto" => Some([decl("overflow-y", "auto")])
    "overflow-y-hidden" => Some([decl("overflow-y", "hidden")])
    "overflow-y-clip" => Some([decl("overflow-y", "clip")])
    "overflow-y-visible" => Some([decl("overflow-y", "visible")])
    "overflow-y-scroll" => Some([decl("overflow-y", "scroll")])
    "overscroll-auto" => Some([decl("overscroll-behavior", "auto")])
    "overscroll-contain" => Some([decl("overscroll-behavior", "contain")])
    "overscroll-none" => Some([decl("overscroll-behavior", "none")])
    "overscroll-x-auto" => Some([decl("overscroll-behavior-x", "auto")])
    "overscroll-x-contain" => Some([decl("overscroll-behavior-x", "contain")])
    "overscroll-x-none" => Some([decl("overscroll-behavior-x", "none")])
    "overscroll-y-auto" => Some([decl("overscroll-behavior-y", "auto")])
    "overscroll-y-contain" => Some([decl("overscroll-behavior-y", "contain")])
    "overscroll-y-none" => Some([decl("overscroll-behavior-y", "none")])
    "scroll-auto" => Some([decl("scroll-behavior", "auto")])
    "scroll-smooth" => Some([decl("scroll-behavior", "smooth")])
    "scrollbar-auto" => Some([decl("scrollbar-width", "auto")])
    "scrollbar-thin" => Some([decl("scrollbar-width", "thin")])
    "scrollbar-none" => Some([decl("scrollbar-width", "none")])
    "select-none" =>
      Some([decl("-webkit-user-select", "none"), decl("user-select", "none")])
    "select-text" =>
      Some([decl("-webkit-user-select", "text"), decl("user-select", "text")])
    "select-all" =>
      Some([decl("-webkit-user-select", "all"), decl("user-select", "all")])
    "select-auto" =>
      Some([decl("-webkit-user-select", "auto"), decl("user-select", "auto")])
    "resize-none" => Some([decl("resize", "none")])
    "resize-x" => Some([decl("resize", "horizontal")])
    "resize-y" => Some([decl("resize", "vertical")])
    "resize" => Some([decl("resize", "both")])
    "snap-none" => Some([decl("scroll-snap-type", "none")])
    "snap-align-none" => Some([decl("scroll-snap-align", "none")])
    "snap-start" => Some([decl("scroll-snap-align", "start")])
    "snap-end" => Some([decl("scroll-snap-align", "end")])
    "snap-center" => Some([decl("scroll-snap-align", "center")])
    "snap-normal" => Some([decl("scroll-snap-stop", "normal")])
    "snap-always" => Some([decl("scroll-snap-stop", "always")])
    "appearance-none" => Some([decl("appearance", "none")])
    "appearance-auto" => Some([decl("appearance", "auto")])
    "touch-auto" => Some([decl("touch-action", "auto")])
    "touch-none" => Some([decl("touch-action", "none")])
    "touch-manipulation" => Some([decl("touch-action", "manipulation")])
    "accent-auto" => Some([decl("accent-color", "auto")])
    "backface-visible" => Some([decl("backface-visibility", "visible")])
    "backface-hidden" => Some([decl("backface-visibility", "hidden")])
    "transform-content" => Some([decl("transform-box", "content-box")])
    "transform-border" => Some([decl("transform-box", "border-box")])
    "transform-fill" => Some([decl("transform-box", "fill-box")])
    "transform-stroke" => Some([decl("transform-box", "stroke-box")])
    "transform-view" => Some([decl("transform-box", "view-box")])
    "flex-row" => Some([decl("flex-direction", "row")])
    "flex-row-reverse" => Some([decl("flex-direction", "row-reverse")])
    "flex-col" => Some([decl("flex-direction", "column")])
    "flex-col-reverse" => Some([decl("flex-direction", "column-reverse")])
    "flex-wrap" => Some([decl("flex-wrap", "wrap")])
    "flex-nowrap" => Some([decl("flex-wrap", "nowrap")])
    "flex-auto" => Some([decl("flex", "auto")])
    "flex-initial" => Some([decl("flex", "0 auto")])
    "flex-none" => Some([decl("flex", "none")])
    "basis-auto" => Some([decl("flex-basis", "auto")])
    "basis-full" => Some([decl("flex-basis", "100%")])
    "grow" => Some([decl("flex-grow", "1")])
    "grow-0" => Some([decl("flex-grow", "0")])
    "shrink" => Some([decl("flex-shrink", "1")])
    "shrink-0" => Some([decl("flex-shrink", "0")])
    "items-start" => Some([decl("align-items", "flex-start")])
    "items-center" => Some([decl("align-items", "center")])
    "items-end" => Some([decl("align-items", "flex-end")])
    "items-center-safe" => Some([decl("align-items", "safe center")])
    "items-end-safe" => Some([decl("align-items", "safe flex-end")])
    "items-baseline" => Some([decl("align-items", "baseline")])
    "items-baseline-last" => Some([decl("align-items", "last baseline")])
    "items-stretch" => Some([decl("align-items", "stretch")])
    "content-normal" => Some([decl("align-content", "normal")])
    "content-center" => Some([decl("align-content", "center")])
    "content-start" => Some([decl("align-content", "flex-start")])
    "content-end" => Some([decl("align-content", "flex-end")])
    "content-between" => Some([decl("align-content", "space-between")])
    "content-around" => Some([decl("align-content", "space-around")])
    "content-evenly" => Some([decl("align-content", "space-evenly")])
    "content-baseline" => Some([decl("align-content", "baseline")])
    "content-stretch" => Some([decl("align-content", "stretch")])
    "justify-start" => Some([decl("justify-content", "flex-start")])
    "justify-center" => Some([decl("justify-content", "center")])
    "justify-end" => Some([decl("justify-content", "flex-end")])
    "justify-between" => Some([decl("justify-content", "space-between")])
    "justify-around" => Some([decl("justify-content", "space-around")])
    "justify-evenly" => Some([decl("justify-content", "space-evenly")])
    "justify-normal" => Some([decl("justify-content", "normal")])
    "justify-center-safe" => Some([decl("justify-content", "safe center")])
    "justify-end-safe" => Some([decl("justify-content", "safe flex-end")])
    "justify-baseline" => Some([decl("justify-content", "baseline")])
    "justify-stretch" => Some([decl("justify-content", "stretch")])
    "place-items-center" => Some([decl("place-items", "center")])
    "place-items-start" => Some([decl("place-items", "start")])
    "place-items-end" => Some([decl("place-items", "end")])
    "place-items-baseline" => Some([decl("place-items", "baseline")])
    "place-items-stretch" => Some([decl("place-items", "stretch")])
    "place-self-auto" => Some([decl("place-self", "auto")])
    "place-self-start" => Some([decl("place-self", "start")])
    "place-self-end" => Some([decl("place-self", "end")])
    "place-self-center" => Some([decl("place-self", "center")])
    "place-self-stretch" => Some([decl("place-self", "stretch")])
    "self-auto" => Some([decl("align-self", "auto")])
    "self-start" => Some([decl("align-self", "flex-start")])
    "self-end" => Some([decl("align-self", "flex-end")])
    "self-center" => Some([decl("align-self", "center")])
    "self-stretch" => Some([decl("align-self", "stretch")])
    "self-baseline" => Some([decl("align-self", "baseline")])
    "justify-self-auto" => Some([decl("justify-self", "auto")])
    "justify-self-start" => Some([decl("justify-self", "flex-start")])
    "justify-self-end" => Some([decl("justify-self", "flex-end")])
    "justify-self-center" => Some([decl("justify-self", "center")])
    "justify-self-stretch" => Some([decl("justify-self", "stretch")])
    "isolate" => Some([decl("isolation", "isolate")])
    "isolation-auto" => Some([decl("isolation", "auto")])
    "float-start" => Some([decl("float", "inline-start")])
    "float-end" => Some([decl("float", "inline-end")])
    "float-right" => Some([decl("float", "right")])
    "float-left" => Some([decl("float", "left")])
    "float-none" => Some([decl("float", "none")])
    "clear-start" => Some([decl("clear", "inline-start")])
    "clear-end" => Some([decl("clear", "inline-end")])
    "clear-right" => Some([decl("clear", "right")])
    "clear-left" => Some([decl("clear", "left")])
    "clear-both" => Some([decl("clear", "both")])
    "clear-none" => Some([decl("clear", "none")])
    "box-border" => Some([decl("box-sizing", "border-box")])
    "box-content" => Some([decl("box-sizing", "content-box")])
    "table-auto" => Some([decl("table-layout", "auto")])
    "table-fixed" => Some([decl("table-layout", "fixed")])
    "caption-top" => Some([decl("caption-side", "top")])
    "caption-bottom" => Some([decl("caption-side", "bottom")])
    "border-collapse" => Some([decl("border-collapse", "collapse")])
    "border-separate" => Some([decl("border-collapse", "separate")])
    "object-contain" => Some([decl("object-fit", "contain")])
    "object-cover" => Some([decl("object-fit", "cover")])
    "object-fill" => Some([decl("object-fit", "fill")])
    "object-none" => Some([decl("object-fit", "none")])
    "object-scale-down" => Some([decl("object-fit", "scale-down")])
    "object-top" => Some([decl("object-position", "top")])
    "object-top-left" => Some([decl("object-position", "left top")])
    "object-top-right" => Some([decl("object-position", "right top")])
    "object-bottom" => Some([decl("object-position", "bottom")])
    "object-bottom-left" => Some([decl("object-position", "left bottom")])
    "object-bottom-right" => Some([decl("object-position", "right bottom")])
    "object-left" => Some([decl("object-position", "left")])
    "object-right" => Some([decl("object-position", "right")])
    "object-center" => Some([decl("object-position", "center")])
    "aspect-auto" => Some([decl("aspect-ratio", "auto")])
    "aspect-square" => Some([decl("aspect-ratio", "1 / 1")])
    "text-left" => Some([decl("text-align", "left")])
    "text-center" => Some([decl("text-align", "center")])
    "text-right" => Some([decl("text-align", "right")])
    "text-justify" => Some([decl("text-align", "justify")])
    "text-ellipsis" => Some([decl("text-overflow", "ellipsis")])
    "text-clip" => Some([decl("text-overflow", "clip")])
    "hyphens-none" =>
      Some([decl("-webkit-hyphens", "none"), decl("hyphens", "none")])
    "hyphens-manual" =>
      Some([decl("-webkit-hyphens", "manual"), decl("hyphens", "manual")])
    "hyphens-auto" =>
      Some([decl("-webkit-hyphens", "auto"), decl("hyphens", "auto")])
    "whitespace-normal" => Some([decl("white-space", "normal")])
    "whitespace-nowrap" => Some([decl("white-space", "nowrap")])
    "whitespace-pre" => Some([decl("white-space", "pre")])
    "whitespace-pre-line" => Some([decl("white-space", "pre-line")])
    "whitespace-pre-wrap" => Some([decl("white-space", "pre-wrap")])
    "whitespace-break-spaces" => Some([decl("white-space", "break-spaces")])
    "text-wrap" => Some([decl("text-wrap", "wrap")])
    "text-nowrap" => Some([decl("text-wrap", "nowrap")])
    "text-balance" => Some([decl("text-wrap", "balance")])
    "text-pretty" => Some([decl("text-wrap", "pretty")])
    "break-normal" =>
      Some([decl("overflow-wrap", "normal"), decl("word-break", "normal")])
    "break-all" => Some([decl("word-break", "break-all")])
    "break-keep" => Some([decl("word-break", "keep-all")])
    "wrap-anywhere" => Some([decl("overflow-wrap", "anywhere")])
    "wrap-break-word" => Some([decl("overflow-wrap", "break-word")])
    "wrap-normal" => Some([decl("overflow-wrap", "normal")])
    "list-inside" => Some([decl("list-style-position", "inside")])
    "list-outside" => Some([decl("list-style-position", "outside")])
    "list-none" => Some([decl("list-style-type", "none")])
    "list-disc" => Some([decl("list-style-type", "disc")])
    "list-decimal" => Some([decl("list-style-type", "decimal")])
    "scrollbar-gutter-auto" => Some([decl("scrollbar-gutter", "auto")])
    "scrollbar-gutter-stable" => Some([decl("scrollbar-gutter", "stable")])
    "scrollbar-gutter-both" =>
      Some([decl("scrollbar-gutter", "stable both-edges")])
    "align-baseline" => Some([decl("vertical-align", "baseline")])
    "align-top" => Some([decl("vertical-align", "top")])
    "align-middle" => Some([decl("vertical-align", "middle")])
    "align-bottom" => Some([decl("vertical-align", "bottom")])
    "align-text-top" => Some([decl("vertical-align", "text-top")])
    "align-text-bottom" => Some([decl("vertical-align", "text-bottom")])
    "align-sub" => Some([decl("vertical-align", "sub")])
    "align-super" => Some([decl("vertical-align", "super")])
    "italic" => Some([decl("font-style", "italic")])
    "not-italic" => Some([decl("font-style", "normal")])
    "uppercase" => Some([decl("text-transform", "uppercase")])
    "lowercase" => Some([decl("text-transform", "lowercase")])
    "capitalize" => Some([decl("text-transform", "capitalize")])
    "normal-case" => Some([decl("text-transform", "none")])
    "underline" => Some([decl("text-decoration-line", "underline")])
    "overline" => Some([decl("text-decoration-line", "overline")])
    "line-through" => Some([decl("text-decoration-line", "line-through")])
    "no-underline" => Some([decl("text-decoration-line", "none")])
    "truncate" =>
      Some([
        decl("overflow", "hidden"),
        decl("text-overflow", "ellipsis"),
        decl("white-space", "nowrap"),
      ])
    "antialiased" =>
      Some([
        decl("-webkit-font-smoothing", "antialiased"),
        decl("-moz-osx-font-smoothing", "grayscale"),
      ])
    "subpixel-antialiased" =>
      Some([
        decl("-webkit-font-smoothing", "auto"),
        decl("-moz-osx-font-smoothing", "auto"),
      ])
    "border" =>
      Some([decl("border-style", "solid"), decl("border-width", "1px")])
    "rounded-none" => Some([decl("border-radius", "0")])
    "rounded-full" => Some([decl("border-radius", "3.40282e38px")])
    "animate-none" => Some([decl("animation", "none")])
    "scale-3d" =>
      Some([
        decl("scale", "var(--tw-scale-x) var(--tw-scale-y) var(--tw-scale-z)"),
      ])
    "scale-none" => Some([decl("scale", "none")])
    "ring-inset" => Some([decl("--tw-ring-inset", "inset")])
    "content-none" =>
      Some([decl("--tw-content", "none"), decl("content", "none")])
    // Generated from the pinned upstream `staticUtility` registrations; every
    // arm here is a plain declaration list with no theme lookup.
    "order-first" => Some([decl("order", "-9999")])
    "order-last" => Some([decl("order", "9999")])
    "order-none" => Some([decl("order", "0")])
    "perspective-origin-center" => Some([decl("perspective-origin", "center")])
    "perspective-origin-top" => Some([decl("perspective-origin", "top")])
    "perspective-origin-top-right" =>
      Some([decl("perspective-origin", "100% 0")])
    "perspective-origin-right" => Some([decl("perspective-origin", "100%")])
    "perspective-origin-bottom-right" =>
      Some([decl("perspective-origin", "100% 100%")])
    "perspective-origin-bottom" => Some([decl("perspective-origin", "bottom")])
    "perspective-origin-bottom-left" =>
      Some([decl("perspective-origin", "0 100%")])
    "perspective-origin-left" => Some([decl("perspective-origin", "0")])
    "perspective-origin-top-left" => Some([decl("perspective-origin", "0 0")])
    "zoom-50" => Some([decl("zoom", "50%")])
    "zoom-100" => Some([decl("zoom", "100%")])
    "break-before-auto" => Some([decl("break-before", "auto")])
    "break-before-avoid" => Some([decl("break-before", "avoid")])
    "break-before-all" => Some([decl("break-before", "all")])
    "break-before-avoid-page" => Some([decl("break-before", "avoid-page")])
    "break-before-page" => Some([decl("break-before", "page")])
    "break-before-left" => Some([decl("break-before", "left")])
    "break-before-right" => Some([decl("break-before", "right")])
    "break-before-column" => Some([decl("break-before", "column")])
    "break-inside-auto" => Some([decl("break-inside", "auto")])
    "break-inside-avoid" => Some([decl("break-inside", "avoid")])
    "break-inside-avoid-page" => Some([decl("break-inside", "avoid-page")])
    "break-inside-avoid-column" => Some([decl("break-inside", "avoid-column")])
    "break-after-auto" => Some([decl("break-after", "auto")])
    "break-after-avoid" => Some([decl("break-after", "avoid")])
    "break-after-all" => Some([decl("break-after", "all")])
    "break-after-avoid-page" => Some([decl("break-after", "avoid-page")])
    "break-after-page" => Some([decl("break-after", "page")])
    "break-after-left" => Some([decl("break-after", "left")])
    "break-after-right" => Some([decl("break-after", "right")])
    "break-after-column" => Some([decl("break-after", "column")])
    "flex-wrap-reverse" => Some([decl("flex-wrap", "wrap-reverse")])
    "place-content-center" => Some([decl("place-content", "center")])
    "place-content-center-safe" => Some([decl("place-content", "safe center")])
    "place-content-start" => Some([decl("place-content", "start")])
    "place-content-end" => Some([decl("place-content", "end")])
    "place-content-end-safe" => Some([decl("place-content", "safe end")])
    "place-content-between" => Some([decl("place-content", "space-between")])
    "place-content-around" => Some([decl("place-content", "space-around")])
    "place-content-evenly" => Some([decl("place-content", "space-evenly")])
    "place-content-baseline" => Some([decl("place-content", "baseline")])
    "place-content-stretch" => Some([decl("place-content", "stretch")])
    "place-items-end-safe" => Some([decl("place-items", "safe end")])
    "place-items-center-safe" => Some([decl("place-items", "safe center")])
    "content-center-safe" => Some([decl("align-content", "safe center")])
    "content-end-safe" => Some([decl("align-content", "safe flex-end")])
    "justify-items-start" => Some([decl("justify-items", "start")])
    "justify-items-end" => Some([decl("justify-items", "end")])
    "justify-items-end-safe" => Some([decl("justify-items", "safe end")])
    "justify-items-center" => Some([decl("justify-items", "center")])
    "justify-items-center-safe" => Some([decl("justify-items", "safe center")])
    "justify-items-stretch" => Some([decl("justify-items", "stretch")])
    "place-self-end-safe" => Some([decl("place-self", "safe end")])
    "place-self-center-safe" => Some([decl("place-self", "safe center")])
    "self-end-safe" => Some([decl("align-self", "safe flex-end")])
    "self-center-safe" => Some([decl("align-self", "safe center")])
    "self-baseline-last" => Some([decl("align-self", "last baseline")])
    "justify-self-end-safe" => Some([decl("justify-self", "safe flex-end")])
    "justify-self-center-safe" => Some([decl("justify-self", "safe center")])
    "break-words" => Some([decl("overflow-wrap", "break-word")])
    "mask-circle" => Some([decl("--tw-mask-radial-shape", "circle")])
    "mask-ellipse" => Some([decl("--tw-mask-radial-shape", "ellipse")])
    "mask-radial-closest-side" =>
      Some([decl("--tw-mask-radial-size", "closest-side")])
    "mask-radial-farthest-side" =>
      Some([decl("--tw-mask-radial-size", "farthest-side")])
    "mask-radial-closest-corner" =>
      Some([decl("--tw-mask-radial-size", "closest-corner")])
    "mask-radial-farthest-corner" =>
      Some([decl("--tw-mask-radial-size", "farthest-corner")])
    "box-decoration-slice" =>
      Some([
        decl("-webkit-box-decoration-break", "slice"),
        decl("box-decoration-break", "slice"),
      ])
    "box-decoration-clone" =>
      Some([
        decl("-webkit-box-decoration-break", "clone"),
        decl("box-decoration-break", "clone"),
      ])
    "mask-clip-border" => Some([decl("mask-clip", "border-box")])
    "mask-clip-padding" => Some([decl("mask-clip", "padding-box")])
    "mask-clip-content" => Some([decl("mask-clip", "content-box")])
    "mask-clip-fill" => Some([decl("mask-clip", "fill-box")])
    "mask-clip-stroke" => Some([decl("mask-clip", "stroke-box")])
    "mask-clip-view" => Some([decl("mask-clip", "view-box")])
    "mask-no-clip" => Some([decl("mask-clip", "no-clip")])
    "mask-origin-border" => Some([decl("mask-origin", "border-box")])
    "mask-origin-padding" => Some([decl("mask-origin", "padding-box")])
    "mask-origin-content" => Some([decl("mask-origin", "content-box")])
    "mask-origin-fill" => Some([decl("mask-origin", "fill-box")])
    "mask-origin-stroke" => Some([decl("mask-origin", "stroke-box")])
    "mask-origin-view" => Some([decl("mask-origin", "view-box")])
    "object-left-bottom" => Some([decl("object-position", "left bottom")])
    "object-left-top" => Some([decl("object-position", "left top")])
    "object-right-bottom" => Some([decl("object-position", "right bottom")])
    "object-right-top" => Some([decl("object-position", "right top")])
    "text-start" => Some([decl("text-align", "start")])
    "text-end" => Some([decl("text-align", "end")])
    "font-stretch-ultra-expanded" =>
      Some([decl("font-stretch", "ultra-expanded")])
    "transition-discrete" =>
      Some([decl("transition-behavior", "allow-discrete")])
    "transition-normal" => Some([decl("transition-behavior", "normal")])
    "will-change-auto" => Some([decl("will-change", "auto")])
    "will-change-contents" => Some([decl("will-change", "contents")])
    "will-change-transform" => Some([decl("will-change", "transform")])
    "will-change-scroll" => Some([decl("will-change", "scroll-position")])
    "contain-none" => Some([decl("contain", "none")])
    "contain-content" => Some([decl("contain", "content")])
    "contain-strict" => Some([decl("contain", "strict")])
    _ => None
  }
}

///|
fn prefixed_value(name : String, prefix : String) -> String? {
  // Equivalent to `name.has_prefix("\{prefix}-")` but WITHOUT allocating the
  // `"\{prefix}-"` marker on every call. This helper is the hottest allocation
  // site in the compile path (~192 calls/candidate), so the per-call marker
  // string dominated allocations. Check the '-' separator first (O(1)) to reject
  // most non-matches before the prefix scan.
  let plen = prefix.length()
  guard name.length() > plen && name[plen] == '-' && name.has_prefix(prefix) else {
    return None
  }
  Some(name[plen + 1:].to_owned())
}

///|
/// Hoisted to a module-level constant so it is built once at startup instead of
/// rebuilt on every candidate (the dispatch scans every utility per candidate).
/// Read-only lookup table.
let directional_spacing_entries : Array[(String, Array[String])] = [
  ("m", ["margin"]),
  ("mx", ["margin-inline"]),
  ("my", ["margin-block"]),
  ("ms", ["margin-inline-start"]),
  ("me", ["margin-inline-end"]),
  ("mbs", ["margin-block-start"]),
  ("mbe", ["margin-block-end"]),
  ("mt", ["margin-top"]),
  ("mr", ["margin-right"]),
  ("mb", ["margin-bottom"]),
  ("ml", ["margin-left"]),
  ("p", ["padding"]),
  ("px", ["padding-inline"]),
  ("py", ["padding-block"]),
  ("ps", ["padding-inline-start"]),
  ("pe", ["padding-inline-end"]),
  ("pbs", ["padding-block-start"]),
  ("pbe", ["padding-block-end"]),
  ("pt", ["padding-top"]),
  ("pr", ["padding-right"]),
  ("pb", ["padding-bottom"]),
  ("pl", ["padding-left"]),
  ("gap-x", ["column-gap"]),
  ("gap-y", ["row-gap"]),
  ("gap", ["gap"]),
]

///|
fn directional_spacing(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  // First-char fast-reject: every entry is margin (m*), padding (p*) or gap (g*),
  // so skip the 25-entry loop for anything else.
  guard name.length() > 0 else { return None }
  let first = name[0]
  guard first == 'm' || first == 'p' || first == 'g' else { return None }
  for entry in directional_spacing_entries {
    let (prefix, properties) = entry
    guard prefixed_value(name, prefix) is Some(raw) else { continue }
    // `m-auto` and its axes are upstream statics; padding and gap have none.
    let value = if raw == "auto" && first == 'm' {
      Some("auto")
    } else {
      resolved_value(theme, raw, "--spacing", true)
    }
    guard value is Some(value) else { return None }
    return Some(properties.map(fn(property) { decl(property, value) }))
  }
  None
}

///|
fn inset_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let entries : Array[(String, String)] = [
    ("inset-x", "inset-inline"),
    ("inset-y", "inset-block"),
    ("inset-s", "inset-inline-start"),
    ("inset-e", "inset-inline-end"),
    ("inset-bs", "inset-block-start"),
    ("inset-be", "inset-block-end"),
    ("inset", "inset"),
    ("top", "top"),
    ("right", "right"),
    ("bottom", "bottom"),
    ("left", "left"),
  ]
  for entry in entries {
    let (prefix, property) = entry
    guard prefixed_value(name, prefix) is Some(raw) else { continue }
    // Upstream registers `<name>-auto` and `<name>-full` alongside the spacing
    // scale for every inset utility.
    let value = match raw {
      "auto" => Some("auto")
      "full" => Some("100%")
      _ => resolved_value(theme, raw, "--inset", true)
    }
    guard value is Some(value) else { return None }
    return Some([decl(property, value)])
  }
  None
}

///|
/// The keyword values the sizing utilities take, verified against the oracle
/// across every prefix. `w`, `h` and `size` accept the viewport units of both
/// axes; the logical utilities take only their own. `auto` is not a maximum and
/// `none` is only a maximum, and `size-*` has no `screen`.
fn sizing_keyword(
  key : String,
  vertical~ : Bool,
  logical~ : Bool,
  maximum~ : Bool,
  screen~ : Bool,
) -> String? {
  match key {
    "auto" => if maximum { None } else { Some("auto") }
    "none" => if maximum { Some("none") } else { None }
    "full" => Some("100%")
    "min" => Some("min-content")
    "max" => Some("max-content")
    "fit" => Some("fit-content")
    "screen" =>
      if screen {
        Some(if vertical { "100vh" } else { "100vw" })
      } else {
        None
      }
    "lh" => if vertical { Some("1lh") } else { None }
    "svw" | "lvw" | "dvw" =>
      if logical && vertical {
        None
      } else {
        Some("100\{key}")
      }
    "svh" | "lvh" | "dvh" =>
      if logical && !vertical {
        None
      } else {
        Some("100\{key}")
      }
    _ => None
  }
}

///|
fn size_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let entries : Array[(String, String, String)] = [
    ("w", "width", "--width"),
    ("min-w", "min-width", "--width"),
    ("max-w", "max-width", "--width"),
    ("h", "height", "--height"),
    ("min-h", "min-height", "--height"),
    ("max-h", "max-height", "--height"),
  ]
  for entry in entries {
    let (prefix, property, theme_namespace) = entry
    guard prefixed_value(name, prefix) is Some(key) else { continue }
    let vertical = property.contains("height")
    let special = sizing_keyword(
      key,
      vertical~,
      logical=false,
      maximum=property.has_prefix("max"),
      screen=true,
    )
    let value = match special {
      Some(v) => Some(v)
      None =>
        // Upstream reads three namespaces in order: the utility's own,
        // `--spacing`, then `--container`.
        match resolved_value(theme, key, theme_namespace, true) {
          Some(value) => Some(value)
          None => theme_css_value(theme, "--container-\{key}")
        }
    }
    guard value is Some(v) else { return None }
    return Some([decl(property, v)])
  }
  None
}

///|
fn paired_size_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  guard prefixed_value(name, "size") is Some(key) else { return None }
  let special = sizing_keyword(
    key,
    vertical=false,
    logical=false,
    maximum=false,
    screen=false,
  )
  let value = match special {
    Some(value) => Some(value)
    None => resolved_value(theme, key, "--size", true)
  }
  guard value is Some(value) else { return None }
  Some([decl("width", value), decl("height", value)])
}

///|
fn color_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  // First-char fast-reject before building/scanning the table: color utilities are
  // border/bg (b), text (t), outline (o), decoration (d), fill (f), stroke (s).
  guard name.length() > 0 else { return None }
  let c = name[0]
  guard c == 'b' || c == 't' || c == 'o' || c == 'd' || c == 'f' || c == 's' else {
    return None
  }
  let entries : Array[(String, String, String)] = [
    ("border-s", "border-inline-start-color", "--border-color"),
    ("border-e", "border-inline-end-color", "--border-color"),
    ("border-bs", "border-block-start-color", "--border-color"),
    ("border-be", "border-block-end-color", "--border-color"),
    ("border-t", "border-top-color", "--border-color"),
    ("border-r", "border-right-color", "--border-color"),
    ("border-b", "border-bottom-color", "--border-color"),
    ("border-l", "border-left-color", "--border-color"),
    ("bg", "background-color", "--background-color"),
    ("text", "color", "--text-color"),
    ("border", "border-color", "--border-color"),
    ("outline", "outline-color", "--outline-color"),
    ("decoration", "text-decoration-color", "--text-decoration-color"),
    ("fill", "fill", "--fill"),
    ("stroke", "stroke", "--stroke"),
  ]
  for entry in entries {
    let (prefix, property, theme_namespace) = entry
    guard prefixed_value(name, prefix) is Some(key) else { continue }
    let value = match arbitrary_value(key) {
      Some(v) => Some(v)
      None =>
        match keyword_color(key) {
          Some(value) => Some(value)
          // Each color utility reads its own namespace before `--color`.
          None =>
            match theme_value(theme, theme_namespace, key) {
              Some(_) => theme_css_value(theme, "\{theme_namespace}-\{key}")
              None =>
                match theme_value(theme, "--color", key) {
                  Some(_) => theme_css_value(theme, "--color-\{key}")
                  None => None
                }
            }
        }
    }
    guard value is Some(v) else { continue }
    return Some([decl(property, v)])
  }
  None
}

///|
/// `content-[…]` routes the value through `--tw-content` so the `before` and
/// `after` variants can reuse it.
fn content_utility(name : String) -> Array[Declaration]? {
  guard prefixed_value(name, "content") is Some(key) else { return None }
  guard arbitrary_value(key) is Some(value) else { return None }
  Some([decl("--tw-content", value), decl("content", "var(--tw-content)")])
}

///|
fn cursor_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  guard prefixed_value(name, "cursor") is Some(key) else { return None }
  let keywords = [
    "auto", "default", "pointer", "wait", "text", "move", "help", "not-allowed",
    "none", "context-menu", "progress", "cell", "crosshair", "vertical-text", "alias",
    "copy", "no-drop", "grab", "grabbing", "all-scroll", "col-resize", "row-resize",
    "n-resize", "e-resize", "s-resize", "w-resize", "ne-resize", "nw-resize", "se-resize",
    "sw-resize", "ew-resize", "ns-resize", "nesw-resize", "nwse-resize", "zoom-in",
    "zoom-out",
  ]
  if keywords.contains(key) {
    return Some([decl("cursor", key)])
  }
  match arbitrary_value(key) {
    Some(value) => Some([decl("cursor", value)])
    None =>
      match theme_value(theme, "--cursor", key) {
        Some(_) =>
          theme_css_value(theme, "--cursor-\{key}").map(fn(value) {
            [decl("cursor", value)]
          })
        None => None
      }
  }
}

///|
/// The three colors upstream's `resolveThemeColor` answers without consulting
/// the theme at all, so every color utility accepts them.
fn keyword_color(key : String) -> String? {
  match key {
    "inherit" => Some("inherit")
    "current" => Some("currentcolor")
    "transparent" => Some("transparent")
    _ => None
  }
}

///|
fn interaction_color_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let (prefix, property, theme_namespace) = if name.has_prefix("accent-") {
    ("accent", "accent-color", "--accent-color")
  } else if name.has_prefix("caret-") {
    ("caret", "caret-color", "--caret-color")
  } else {
    return None
  }
  guard prefixed_value(name, prefix) is Some(key) else { return None }
  let value = match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match keyword_color(key) {
        Some(value) => Some(value)
        None =>
          match theme_value(theme, theme_namespace, key) {
            Some(_) => theme_css_value(theme, "\{theme_namespace}-\{key}")
            None =>
              match theme_value(theme, "--color", key) {
                Some(_) => theme_css_value(theme, "--color-\{key}")
                None => None
              }
          }
      }
  }
  value.map(fn(value) { [decl(property, value)] })
}

///|
fn grid_track_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let (prefix, property, theme_namespace) = if name.has_prefix("grid-cols-") {
    ("grid-cols", "grid-template-columns", "--grid-template-columns")
  } else if name.has_prefix("grid-rows-") {
    ("grid-rows", "grid-template-rows", "--grid-template-rows")
  } else if name.has_prefix("auto-cols-") {
    ("auto-cols", "grid-auto-columns", "--grid-auto-columns")
  } else if name.has_prefix("auto-rows-") {
    ("auto-rows", "grid-auto-rows", "--grid-auto-rows")
  } else {
    return None
  }
  guard prefixed_value(name, prefix) is Some(key) else { return None }
  let value = match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match theme_value(theme, theme_namespace, key) {
        Some(_) => theme_css_value(theme, "\{theme_namespace}-\{key}")
        None =>
          if (prefix == "grid-cols" || prefix == "grid-rows") &&
            is_nonnegative_integer(key) &&
            key != "0" {
            Some("repeat(\{key}, minmax(0, 1fr))")
          } else if prefix == "auto-cols" || prefix == "auto-rows" {
            // `auto-cols-12` is a spacing multiplier, unlike the track counts
            // the explicit grids take.
            numeric_spacing(theme, key)
          } else {
            None
          }
      }
  }
  value.map(fn(value) { [decl(property, value)] })
}

///|
fn grid_placement_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let entries : Array[(String, String, String?, Bool)] = [
    ("col-span", "grid-column", None, true),
    ("col-start", "grid-column-start", Some("--grid-column-start"), false),
    ("col-end", "grid-column-end", Some("--grid-column-end"), false),
    ("row-span", "grid-row", None, true),
    ("row-start", "grid-row-start", Some("--grid-row-start"), false),
    ("row-end", "grid-row-end", Some("--grid-row-end"), false),
    ("col", "grid-column", Some("--grid-column"), false),
    ("row", "grid-row", Some("--grid-row"), false),
  ]
  for entry in entries {
    let (prefix, property, theme_namespace, span) = entry
    guard prefixed_value(name, prefix) is Some(key) else { continue }
    let value = match arbitrary_value(key) {
      Some(value) =>
        Some(if span { "span \{value} / span \{value}" } else { value })
      None =>
        match theme_namespace {
          Some(theme_namespace) =>
            match theme_value(theme, theme_namespace, key) {
              Some(_) => theme_css_value(theme, "\{theme_namespace}-\{key}")
              None => None
            }
          None => None
        }
    }
    let value = match value {
      Some(value) => Some(value)
      None =>
        if is_nonnegative_integer(key) && key != "0" {
          Some(if span { "span \{key} / span \{key}" } else { key })
        } else {
          None
        }
    }
    guard value is Some(value) else { return None }
    return Some([decl(property, value)])
  }
  None
}

///|
fn line_clamp_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  guard prefixed_value(name, "line-clamp") is Some(key) else { return None }
  let value = match arbitrary_value(key) {
    Some(value) => Some(value)
    None => theme_css_value(theme, "--line-clamp-\{key}")
  }
  // `line-clamp-none` releases the clamp, unless the theme claims the name.
  guard value is Some(value) else {
    if key == "none" {
      return Some([
        decl("overflow", "visible"),
        decl("display", "block"),
        decl("-webkit-box-orient", "horizontal"),
        decl("-webkit-line-clamp", "unset"),
      ])
    }
    guard is_nonnegative_integer(key) && key != "0" else { return None }
    return Some([
      decl("overflow", "hidden"),
      decl("display", "-webkit-box"),
      decl("-webkit-box-orient", "vertical"),
      decl("-webkit-line-clamp", key),
    ])
  }
  Some([
    decl("overflow", "hidden"),
    decl("display", "-webkit-box"),
    decl("-webkit-box-orient", "vertical"),
    decl("-webkit-line-clamp", value),
  ])
}

///|
fn columns_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  guard prefixed_value(name, "columns") is Some(key) else { return None }
  let value = match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match theme_css_value(theme, "--columns-\{key}") {
        Some(value) => Some(value)
        None =>
          match theme_css_value(theme, "--container-\{key}") {
            // `columns-3xs` is a container width, not a count.
            Some(value) => Some(value)
            None =>
              if is_nonnegative_integer(key) && key != "0" {
                Some(key)
              } else {
                None
              }
          }
      }
  }
  value.map(fn(value) { [decl("columns", value)] })
}

///|
fn logical_size_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let entries : Array[(String, String, Bool)] = [
    ("min-inline", "min-inline-size", false),
    ("max-inline", "max-inline-size", false),
    ("inline", "inline-size", false),
    ("min-block", "min-block-size", true),
    ("max-block", "max-block-size", true),
    ("block", "block-size", true),
  ]
  for entry in entries {
    let (prefix, property, vertical) = entry
    guard prefixed_value(name, prefix) is Some(key) else { continue }
    let special = sizing_keyword(
      key,
      vertical~,
      logical=true,
      maximum=property.has_prefix("max"),
      screen=true,
    )
    let value = match special {
      Some(value) => Some(value)
      None =>
        match theme_css_value(theme, "--container-\{key}") {
          Some(value) => Some(value)
          None => resolved_value(theme, key, "--size", true)
        }
    }
    guard value is Some(value) else { return None }
    return Some([decl(property, value)])
  }
  None
}

///|
fn scroll_spacing_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let entries : Array[(String, String)] = [
    ("scroll-mx", "scroll-margin-inline"),
    ("scroll-my", "scroll-margin-block"),
    ("scroll-ms", "scroll-margin-inline-start"),
    ("scroll-me", "scroll-margin-inline-end"),
    ("scroll-mbs", "scroll-margin-block-start"),
    ("scroll-mbe", "scroll-margin-block-end"),
    ("scroll-mt", "scroll-margin-top"),
    ("scroll-mr", "scroll-margin-right"),
    ("scroll-mb", "scroll-margin-bottom"),
    ("scroll-ml", "scroll-margin-left"),
    ("scroll-m", "scroll-margin"),
    ("scroll-px", "scroll-padding-inline"),
    ("scroll-py", "scroll-padding-block"),
    ("scroll-ps", "scroll-padding-inline-start"),
    ("scroll-pe", "scroll-padding-inline-end"),
    ("scroll-pbs", "scroll-padding-block-start"),
    ("scroll-pbe", "scroll-padding-block-end"),
    ("scroll-pt", "scroll-padding-top"),
    ("scroll-pr", "scroll-padding-right"),
    ("scroll-pb", "scroll-padding-bottom"),
    ("scroll-pl", "scroll-padding-left"),
    ("scroll-p", "scroll-padding"),
  ]
  for entry in entries {
    let (prefix, property) = entry
    guard prefixed_value(name, prefix) is Some(key) else { continue }
    guard resolved_value(theme, key, "--scroll-spacing", true) is Some(value) else {
      return None
    }
    return Some([decl(property, value)])
  }
  None
}

///|
fn order_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  guard prefixed_value(name, "order") is Some(key) else { return None }
  let value = match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match theme_css_value(theme, "--order-\{key}") {
        Some(value) => Some(value)
        None => if is_nonnegative_integer(key) { Some(key) } else { None }
      }
  }
  value.map(fn(value) { [decl("order", value)] })
}

///|
fn flex_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  if name == "flex-auto" {
    return Some([decl("flex", "auto")])
  }
  if name == "flex-initial" {
    return Some([decl("flex", "0 auto")])
  }
  if name == "flex-none" {
    return Some([decl("flex", "none")])
  }
  if name.has_prefix("flex-") {
    let key = name[5:].to_owned()
    let value = match arbitrary_value(key) {
      Some(value) => Some(value)
      None =>
        match theme_css_value(theme, "--flex-\{key}") {
          Some(value) => Some(value)
          None =>
            if is_nonnegative_integer(key) {
              Some(key)
            } else if is_ratio(key) {
              // `flex` keeps the fraction as written, unlike the sizing
              // utilities which space it out.
              Some("calc(\{key} * 100%)")
            } else {
              None
            }
        }
    }
    return value.map(fn(value) { [decl("flex", value)] })
  }
  if name == "grow" || name == "shrink" {
    return Some([
      decl(if name == "grow" { "flex-grow" } else { "flex-shrink" }, "1"),
    ])
  }
  for entry in [("grow", "flex-grow"), ("shrink", "flex-shrink")] {
    let (prefix, property) = entry
    guard prefixed_value(name, prefix) is Some(key) else { continue }
    let value = match arbitrary_value(key) {
      Some(value) => value
      None => if is_nonnegative_integer(key) { key } else { return None }
    }
    return Some([decl(property, value)])
  }
  None
}

///|
fn basis_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  guard prefixed_value(name, "basis") is Some(key) else { return None }
  let value = match arbitrary_value(key) {
    Some(value) => Some(value)
    None =>
      match key.split_once("/") {
        Some((numerator, denominator)) if is_nonnegative_integer(
            numerator.to_owned(),
          ) &&
          is_nonnegative_integer(denominator.to_owned()) &&
          denominator != "0" =>
          Some("calc(\{numerator} / \{denominator} * 100%)")
        _ =>
          match theme_css_value(theme, "--flex-basis-\{key}") {
            Some(value) => Some(value)
            None => resolved_value(theme, key, "--basis", true)
          }
      }
  }
  value.map(fn(value) { [decl("flex-basis", value)] })
}

///|
fn border_spacing_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  let (key, axis) = if name.has_prefix("border-spacing-x-") {
    (name[17:].to_owned(), "x")
  } else if name.has_prefix("border-spacing-y-") {
    (name[17:].to_owned(), "y")
  } else if name.has_prefix("border-spacing-") {
    (name[15:].to_owned(), "both")
  } else {
    return None
  }
  guard resolved_value(theme, key, "--border-spacing", true) is Some(value) else {
    return None
  }
  let declarations : Array[Declaration] = []
  if axis == "x" || axis == "both" {
    declarations.push(decl("--tw-border-spacing-x", value))
  }
  if axis == "y" || axis == "both" {
    declarations.push(decl("--tw-border-spacing-y", value))
  }
  declarations.push(
    decl(
      "border-spacing", "var(--tw-border-spacing-x) var(--tw-border-spacing-y)",
    ),
  )
  Some(declarations)
}

///|
fn descriptor_utility(name : String) -> Array[Declaration]? {
  let descriptors : Array[(String, String, String)] = [
    ("scheme-normal", "color-scheme", "normal"),
    ("scheme-light", "color-scheme", "light"),
    ("scheme-dark", "color-scheme", "dark"),
    ("scheme-light-dark", "color-scheme", "light dark"),
    ("scheme-only-light", "color-scheme", "only light"),
    ("scheme-only-dark", "color-scheme", "only dark"),
    ("forced-color-adjust-auto", "forced-color-adjust", "auto"),
    ("forced-color-adjust-none", "forced-color-adjust", "none"),
    ("bg-blend-normal", "background-blend-mode", "normal"),
    ("bg-blend-multiply", "background-blend-mode", "multiply"),
    ("bg-blend-screen", "background-blend-mode", "screen"),
    ("bg-blend-overlay", "background-blend-mode", "overlay"),
    ("bg-blend-darken", "background-blend-mode", "darken"),
    ("bg-blend-lighten", "background-blend-mode", "lighten"),
    ("bg-blend-color-dodge", "background-blend-mode", "color-dodge"),
    ("bg-blend-color-burn", "background-blend-mode", "color-burn"),
    ("bg-blend-hard-light", "background-blend-mode", "hard-light"),
    ("bg-blend-soft-light", "background-blend-mode", "soft-light"),
    ("bg-blend-difference", "background-blend-mode", "difference"),
    ("bg-blend-exclusion", "background-blend-mode", "exclusion"),
    ("bg-blend-hue", "background-blend-mode", "hue"),
    ("bg-blend-saturation", "background-blend-mode", "saturation"),
    ("bg-blend-color", "background-blend-mode", "color"),
    ("bg-blend-luminosity", "background-blend-mode", "luminosity"),
    ("mix-blend-normal", "mix-blend-mode", "normal"),
    ("mix-blend-multiply", "mix-blend-mode", "multiply"),
    ("mix-blend-screen", "mix-blend-mode", "screen"),
    ("mix-blend-overlay", "mix-blend-mode", "overlay"),
    ("mix-blend-darken", "mix-blend-mode", "darken"),
    ("mix-blend-lighten", "mix-blend-mode", "lighten"),
    ("mix-blend-color-dodge", "mix-blend-mode", "color-dodge"),
    ("mix-blend-color-burn", "mix-blend-mode", "color-burn"),
    ("mix-blend-hard-light", "mix-blend-mode", "hard-light"),
    ("mix-blend-soft-light", "mix-blend-mode", "soft-light"),
    ("mix-blend-difference", "mix-blend-mode", "difference"),
    ("mix-blend-exclusion", "mix-blend-mode", "exclusion"),
    ("mix-blend-hue", "mix-blend-mode", "hue"),
    ("mix-blend-saturation", "mix-blend-mode", "saturation"),
    ("mix-blend-color", "mix-blend-mode", "color"),
    ("mix-blend-luminosity", "mix-blend-mode", "luminosity"),
    ("mix-blend-plus-darker", "mix-blend-mode", "plus-darker"),
    ("mix-blend-plus-lighter", "mix-blend-mode", "plus-lighter"),
  ]
  for entry in descriptors {
    let (utility_name, property, value) = entry
    if utility_name == name {
      return Some([decl(property, value)])
    }
  }
  None
}

///|
fn list_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  if name.has_prefix("list-image-") {
    let key = name[11:].to_owned()
    let value = match arbitrary_value(key) {
      Some(value) => Some(value)
      None =>
        match theme_css_value(theme, "--list-style-image-\{key}") {
          Some(value) => Some(value)
          None => if key == "none" { Some("none") } else { None }
        }
    }
    return value.map(fn(value) { [decl("list-style-image", value)] })
  }
  guard prefixed_value(name, "list") is Some(key) else { return None }
  let value = match arbitrary_value(key) {
    Some(value) => Some(value)
    None => theme_css_value(theme, "--list-style-type-\{key}")
  }
  value.map(fn(value) { [decl("list-style-type", value)] })
}

///|
fn scalar_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  if name.has_prefix("opacity-") {
    let key = name[8:].to_owned()
    let value = match arbitrary_value(key) {
      Some(value) => Some(value)
      None =>
        match theme_css_value(theme, "--opacity-\{key}") {
          Some(value) => Some(value)
          None => if is_spacing_number(key) { Some("\{key}%") } else { None }
        }
    }
    return value.map(fn(value) { [decl("opacity", value)] })
  }
  if name.has_prefix("align-") {
    let key = name[6:].to_owned()
    return arbitrary_value(key).map(fn(value) {
      [decl("vertical-align", value)]
    })
  }
  if name.has_prefix("tab-") {
    let key = name[4:].to_owned()
    let value = match arbitrary_value(key) {
      Some(value) => Some(value)
      None =>
        if is_nonnegative_integer(key) {
          Some(key)
        } else {
          theme_css_value(theme, "--tab-size-\{key}")
        }
    }
    return value.map(fn(value) { [decl("tab-size", value)] })
  }
  None
}

///|
fn dynamic_utility(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  // Try each dynamic utility in order, returning the first match. Each utility is
  // invoked ONCE (the previous `guard util(...) is None else { return util(...) }`
  // form called every matching utility twice — the test and the return); `as r`
  // returns the already-computed Option without recomputing or rewrapping.
  match descriptor_utility(name) {
    Some(_) as r => return r
    None => ()
  }
  match list_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match scalar_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match line_clamp_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match columns_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match logical_size_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match scroll_spacing_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match order_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match flex_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match basis_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match border_spacing_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match directional_spacing(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match inset_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match paired_size_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match size_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match color_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match content_utility(name) {
    Some(_) as r => return r
    None => ()
  }
  match cursor_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match interaction_color_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match grid_track_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  match grid_placement_utility(theme, name) {
    Some(_) as r => return r
    None => ()
  }
  if name.has_prefix("animate-") {
    let key = name[8:].to_owned()
    match arbitrary_value(key) {
      Some(value) => return Some([decl("animation", value)])
      None => ()
    }
    match theme_css_value(theme, "--animate-\{key}") {
      Some(value) => return Some([decl("animation", value)])
      None => ()
    }
  }
  if name.has_prefix("aspect-") {
    let key = name[7:].to_owned()
    let value = match arbitrary_value(key) {
      Some(value) => Some(value)
      None =>
        match theme_value(theme, "--aspect", key) {
          Some(_) => theme_css_value(theme, "--aspect-\{key}")
          // A bare ratio is the value itself, not a division.
          None => if is_ratio(key) { Some(key) } else { None }
        }
    }
    match value {
      Some(value) => return Some([decl("aspect-ratio", value)])
      None => ()
    }
  }
  if name.has_prefix("object-") {
    let key = name[7:].to_owned()
    let value = match arbitrary_value(key) {
      Some(value) => Some(value)
      None =>
        match theme_value(theme, "--object-position", key) {
          Some(_) => theme_css_value(theme, "--object-position-\{key}")
          None => None
        }
    }
    match value {
      Some(value) => return Some([decl("object-position", value)])
      None => ()
    }
  }
  if name.has_prefix("font-") {
    let key = name[5:].to_owned()
    match theme_value(theme, "--font-weight", key) {
      Some(_) =>
        match theme_css_value(theme, "--font-weight-\{key}") {
          Some(value) =>
            // Upstream also sets the registered `--tw-font-weight` custom
            // property so later utilities can compose the weight.
            return Some([
              decl("--tw-font-weight", value),
              decl("font-weight", value),
            ])
          None => ()
        }
      None => ()
    }
  }
  if prefixed_value(name, "font-stretch") is Some(key) {
    match arbitrary_value(key) {
      Some(value) => return Some([decl("font-stretch", value)])
      None => ()
    }
    // A percentage from 50% to 200%, whole numbers only.
    if key.has_suffix("%") {
      let number = key[:key.length() - 1].to_owned()
      if is_nonnegative_integer(number) {
        let percentage = @string.parse_double(number) catch { _ => 0.0 }
        if percentage >= 50.0 && percentage <= 200.0 {
          return Some([decl("font-stretch", key)])
        }
      }
    }
    return None
  }
  if prefixed_value(name, "zoom") is Some(key) {
    match arbitrary_value(key) {
      Some(value) => return Some([decl("zoom", value)])
      None => ()
    }
  }
  if prefixed_value(name, "will-change") is Some(key) {
    match arbitrary_value(key) {
      Some(value) => return Some([decl("will-change", value)])
      None => ()
    }
  }
  if name.has_prefix("z-") {
    let key = name[2:].to_owned()
    // Upstream: an arbitrary value, a `--z-index-*` theme key, a positive
    // integer, or the static `auto`. Anything else is not a candidate.
    let value = match arbitrary_value(key) {
      Some(value) => Some(value)
      None =>
        match theme_css_value(theme, "--z-index-\{key}") {
          Some(value) => Some(value)
          None =>
            if is_nonnegative_integer(key) {
              Some(key)
            } else if key == "auto" {
              // A static value, and so last: `--z-index-auto` wins over it.
              Some("auto")
            } else {
              None
            }
        }
    }
    match value {
      Some(value) => return Some([decl("z-index", value)])
      None => return None
    }
  }
  if name.has_prefix("[") && name.has_suffix("]") {
    let inner = name[1:name.length() - 1].to_owned()
    guard inner.split_once(":") is Some((property, value)) else { return None }
    return Some([decl(property.to_owned(), decode_arbitrary(value.to_owned()))])
  }
  None
}

///|
/// A compiled utility body, and whether the candidate's `/modifier` found a
/// taker. Upstream's functional utilities bail out on a modifier nothing
/// consumes, so `render_candidate` needs to know rather than quietly dropping it.
priv struct CompiledBase {
  declarations : Array[Declaration]
  modifier_used : Bool
  /// Upstream reaches a utility's static values only when the candidate is not
  /// negative, so `-order-first` and `-z-auto` do not exist.
  static_value : Bool
}

///|
/// Most families never look at the modifier themselves: its only later reader is
/// the alpha channel `apply_candidate_value` applies to a color declaration.
fn alpha_base(declarations : Array[Declaration]) -> CompiledBase {
  {
    declarations,
    modifier_used: declarations.iter().any(fn(declaration) {
      is_alpha_property(declaration.property)
    }),
    static_value: false,
  }
}

///|
fn compile_base(
  theme : Map[String, String],
  name : String,
  modifier : String?,
) -> CompiledBase? {
  // `w-1/2` and `translate-1/2` reach us as a value plus a modifier, because a
  // fraction and a modifier are spelled the same. A utility that takes
  // fractions matches on the joined name, and a match means the `/` was its
  // own. Color utilities are exempt: there the `/` really is an alpha channel.
  let color_candidate = name.has_prefix("bg-") ||
    name.has_prefix("text-") ||
    name.has_prefix("border-") ||
    name.has_prefix("outline-") ||
    name.has_prefix("decoration-") ||
    name.has_prefix("fill-") ||
    name.has_prefix("stroke-") ||
    name.has_prefix("accent-") ||
    name.has_prefix("caret-")
  if modifier is Some(fraction) && !color_candidate && supports_fractions(name) {
    match compile_base(theme, "\{name}/\{fraction}", None) {
      Some(base) => return Some({ ..base, modifier_used: true })
      None => ()
    }
  }
  match stateful_transform_utility(theme, name) {
    Some(declarations) => return Some(alpha_base(declarations))
    None => ()
  }
  match stateful_effect_utility(theme, name) {
    Some(declarations) => return Some(alpha_base(declarations))
    None => ()
  }
  match stateful_filter_transition_utility(theme, name) {
    Some(declarations) => return Some(alpha_base(declarations))
    None => ()
  }
  match typography_utility(theme, name, modifier) {
    Some((declarations, used)) => {
      let base = alpha_base(declarations)
      return Some({ ..base, modifier_used: base.modifier_used || used })
    }
    None => ()
  }
  match border_utility(theme, name) {
    Some(declarations) => return Some(alpha_base(declarations))
    None => ()
  }
  match background_utility(theme, name) {
    Some(declarations) => return Some(alpha_base(declarations))
    None => ()
  }
  match dynamic_utility(theme, name) {
    Some(declarations) => Some(alpha_base(declarations))
    // Static values come last: upstream resolves a utility's theme keys
    // first, so `--order-first` in the theme beats the built-in `order-first`.
    None =>
      static_utility(name).map(fn(value) {
        { ..alpha_base(value), static_value: true }
      })
  }
}
