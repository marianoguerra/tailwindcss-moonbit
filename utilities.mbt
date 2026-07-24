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
fn apply_alpha(value : String, modifier : String) -> String {
  let alpha = match arbitrary_value(modifier) {
    Some(value) => value
    None => "\{modifier}%"
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
  let spacing_prefix = "calc(var(--spacing) * "
  if value.has_prefix(spacing_prefix) && value.has_suffix(")") {
    let factor = value[spacing_prefix.length():value.length() - 1].to_owned()
    "calc(var(--spacing) * -\{factor})"
  } else if value == "100%" {
    "-100%"
  } else if value == "var(--spacing)" {
    "calc(var(--spacing) * -1)"
  } else {
    "calc(\{value} * -1)"
  }
}

///|
fn apply_candidate_value(
  theme : Map[String, String],
  declarations : Array[Declaration],
  negative : Bool,
  modifier : String?,
) -> Array[Declaration] {
  declarations.map(fn(declaration) {
    let (value, fallback) = match modifier {
      Some(alpha) =>
        if declaration.property == "color" ||
          declaration.property.has_suffix("-color") ||
          declaration.property == "fill" ||
          declaration.property == "stroke" ||
          declaration.property == "--tw-gradient-from" ||
          declaration.property == "--tw-gradient-via" ||
          declaration.property == "--tw-gradient-to" {
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
  })
}

///|
fn numeric_spacing(theme : Map[String, String], value : String) -> String? {
  if value == "px" {
    return Some("1px")
  }
  if value == "full" {
    return Some("100%")
  }
  if value == "auto" {
    return Some("auto")
  }
  guard theme_css_value(theme, "--spacing") is Some(base) else { return None }
  if value == "1" {
    Some(base)
  } else {
    Some("calc(\{base} * \{value})")
  }
}

///|
fn arbitrary_value(value : String) -> String? {
  if value.has_prefix("[") && value.has_suffix("]") && value.length() >= 2 {
    Some(decode_arbitrary(value[1:value.length() - 1].to_owned()))
  } else {
    None
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
  ("gap", ["gap"]),
  ("gap-x", ["column-gap"]),
  ("gap-y", ["row-gap"]),
]

///|
fn directional_spacing(
  theme : Map[String, String],
  name : String,
) -> Array[Declaration]? {
  for entry in directional_spacing_entries {
    let (prefix, properties) = entry
    guard prefixed_value(name, prefix) is Some(raw) else { continue }
    guard resolved_value(theme, raw, "--spacing", true) is Some(value) else {
      return None
    }
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
    guard resolved_value(theme, raw, "--inset", true) is Some(value) else {
      return None
    }
    return Some([decl(property, value)])
  }
  None
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
    let special = match key {
      "screen" => Some(if vertical { "100vh" } else { "100vw" })
      "svh" => Some("100svh")
      "lvh" => Some("100lvh")
      "dvh" => Some("100dvh")
      "lh" => Some("1lh")
      "min" => Some("min-content")
      "max" => Some("max-content")
      "fit" => Some("fit-content")
      "none" => if property.has_prefix("max") { Some("none") } else { None }
      _ => None
    }
    let value = match special {
      Some(v) => Some(v)
      None =>
        match resolved_value(theme, key, theme_namespace, false) {
          Some(value) => Some(value)
          None =>
            match theme_css_value(theme, "--container-\{key}") {
              Some(value) => Some(value)
              None => resolved_value(theme, key, theme_namespace, true)
            }
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
  let special = match key {
    "auto" => Some("auto")
    "full" => Some("100%")
    "min" => Some("min-content")
    "max" => Some("max-content")
    "fit" => Some("fit-content")
    _ => None
  }
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
  let entries : Array[(String, String)] = [
    ("border-x", "border-inline-color"),
    ("border-y", "border-block-color"),
    ("border-s", "border-inline-start-color"),
    ("border-e", "border-inline-end-color"),
    ("border-bs", "border-block-start-color"),
    ("border-be", "border-block-end-color"),
    ("border-t", "border-top-color"),
    ("border-r", "border-right-color"),
    ("border-b", "border-bottom-color"),
    ("border-l", "border-left-color"),
    ("bg", "background-color"),
    ("text", "color"),
    ("border", "border-color"),
    ("outline", "outline-color"),
    ("decoration", "text-decoration-color"),
    ("fill", "fill"),
    ("stroke", "stroke"),
  ]
  for entry in entries {
    let (prefix, property) = entry
    guard prefixed_value(name, prefix) is Some(key) else { continue }
    let value = match arbitrary_value(key) {
      Some(v) => Some(v)
      None =>
        match key {
          "inherit" => Some("inherit")
          "current" => Some("currentcolor")
          "transparent" => Some("transparent")
          _ =>
            match theme_value(theme, "--color", key) {
              Some(_) => theme_css_value(theme, "--color-\{key}")
              None => None
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
      match theme_value(theme, theme_namespace, key) {
        Some(_) => theme_css_value(theme, "\{theme_namespace}-\{key}")
        None =>
          match theme_value(theme, "--color", key) {
            Some(_) => theme_css_value(theme, "--color-\{key}")
            None => None
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
fn line_clamp_utility(name : String) -> Array[Declaration]? {
  guard prefixed_value(name, "line-clamp") is Some(value) else { return None }
  if value == "none" {
    return Some([
      decl("overflow", "visible"),
      decl("display", "block"),
      decl("-webkit-box-orient", "horizontal"),
      decl("-webkit-line-clamp", "unset"),
    ])
  }
  let value = match arbitrary_value(value) {
    Some(value) => value
    None =>
      if is_nonnegative_integer(value) && value != "0" {
        value
      } else {
        return None
      }
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
          if is_nonnegative_integer(key) && key != "0" {
            Some(key)
          } else {
            None
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
    let special = match key {
      "auto" => Some("auto")
      "full" => Some("100%")
      "min" => Some("min-content")
      "max" => Some("max-content")
      "fit" => Some("fit-content")
      "screen" => Some(if vertical { "100vh" } else { "100vw" })
      "none" => if property.has_prefix("max") { Some("none") } else { None }
      _ => None
    }
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
          None => if is_nonnegative_integer(key) { Some(key) } else { None }
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
  if name == "list-image-none" {
    return Some([decl("list-style-image", "none")])
  }
  if name.has_prefix("list-image-") {
    let key = name[11:].to_owned()
    let value = match arbitrary_value(key) {
      Some(value) => Some(value)
      None => theme_css_value(theme, "--list-style-image-\{key}")
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
  guard descriptor_utility(name) is None else {
    return descriptor_utility(name)
  }
  guard list_utility(theme, name) is None else {
    return list_utility(theme, name)
  }
  guard scalar_utility(theme, name) is None else {
    return scalar_utility(theme, name)
  }
  guard line_clamp_utility(name) is None else {
    return line_clamp_utility(name)
  }
  guard columns_utility(theme, name) is None else {
    return columns_utility(theme, name)
  }
  guard logical_size_utility(theme, name) is None else {
    return logical_size_utility(theme, name)
  }
  guard scroll_spacing_utility(theme, name) is None else {
    return scroll_spacing_utility(theme, name)
  }
  guard order_utility(theme, name) is None else {
    return order_utility(theme, name)
  }
  guard flex_utility(theme, name) is None else {
    return flex_utility(theme, name)
  }
  guard basis_utility(theme, name) is None else {
    return basis_utility(theme, name)
  }
  guard border_spacing_utility(theme, name) is None else {
    return border_spacing_utility(theme, name)
  }
  guard directional_spacing(theme, name) is None else {
    return directional_spacing(theme, name)
  }
  guard inset_utility(theme, name) is None else {
    return inset_utility(theme, name)
  }
  guard paired_size_utility(theme, name) is None else {
    return paired_size_utility(theme, name)
  }
  guard size_utility(theme, name) is None else {
    return size_utility(theme, name)
  }
  guard color_utility(theme, name) is None else {
    return color_utility(theme, name)
  }
  guard content_utility(name) is None else { return content_utility(name) }
  guard cursor_utility(theme, name) is None else {
    return cursor_utility(theme, name)
  }
  guard interaction_color_utility(theme, name) is None else {
    return interaction_color_utility(theme, name)
  }
  guard grid_track_utility(theme, name) is None else {
    return grid_track_utility(theme, name)
  }
  guard grid_placement_utility(theme, name) is None else {
    return grid_placement_utility(theme, name)
  }
  if name.has_prefix("animate-") {
    let key = name[8:].to_owned()
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
          None => None
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
  if name.has_prefix("z-") {
    return Some([decl("z-index", name[2:].to_owned())])
  }
  if name.has_prefix("[") && name.has_suffix("]") {
    let inner = name[1:name.length() - 1].to_owned()
    guard inner.split_once(":") is Some((property, value)) else { return None }
    return Some([decl(property.to_owned(), decode_arbitrary(value.to_owned()))])
  }
  None
}

///|
fn compile_base(
  theme : Map[String, String],
  name : String,
  modifier : String?,
) -> Array[Declaration]? {
  match stateful_transform_utility(theme, name) {
    Some(declarations) => return Some(declarations)
    None => ()
  }
  match stateful_effect_utility(theme, name) {
    Some(declarations) => return Some(declarations)
    None => ()
  }
  match stateful_filter_transition_utility(theme, name) {
    Some(declarations) => return Some(declarations)
    None => ()
  }
  match typography_utility(theme, name, modifier) {
    Some(declarations) => return Some(declarations)
    None => ()
  }
  match border_utility(theme, name) {
    Some(declarations) => return Some(declarations)
    None => ()
  }
  match background_utility(theme, name) {
    Some(declarations) => return Some(declarations)
    None => ()
  }
  match static_utility(name) {
    Some(value) => Some(value)
    None => {
      let color_candidate = name.has_prefix("bg-") ||
        name.has_prefix("text-") ||
        name.has_prefix("border-") ||
        name.has_prefix("outline-") ||
        name.has_prefix("decoration-") ||
        name.has_prefix("fill-") ||
        name.has_prefix("stroke-") ||
        name.has_prefix("accent-") ||
        name.has_prefix("caret-")
      let dynamic_name = match modifier {
        Some(modifier) if !color_candidate => "\{name}/\{modifier}"
        _ => name
      }
      dynamic_utility(theme, dynamic_name)
    }
  }
}
