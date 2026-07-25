///|
test "scan_html: plain fragment" {
  let scan = scan_html(
    (
      #|<div class="card bg-base-100 shadow">
      #|  <button class="btn btn-primary">Go</button>
      #|</div>
    ),
  )
  debug_inspect(
    scan.candidates,
    content=(
      #|["card", "bg-base-100", "shadow", "btn", "btn-primary"]
    ),
  )
  debug_inspect(
    (scan.elements, scan.class_attrs),
    content=(
      #|(2, 2)
    ),
  )
}

///|
/// The reason `scan_html` wraps its input in `<template>`: a table-context
/// fragment with no ancestor table is dropped outright by tree construction, so
/// a plain document parse loses every class on it.
test "scan_html: table fragments keep their classes" {
  let fragment =
    #|<tr class="hover">
    #|  <td class="p-2">cell</td>
    #|  <th class="text-right">head</th>
    #|</tr>
  debug_inspect(
    scan_html(fragment).candidates,
    content=(
      #|["hover", "p-2", "text-right"]
    ),
  )
  // Same input parsed as a document: the rows are gone, and so are the classes.
  debug_inspect(
    @html5.parse(fragment).to_html(),
    content=(
      #|"<html><head></head><body>\n  cell\n  head\n</body></html>"
    ),
  )
  debug_inspect(
    scan_html("<tbody class=\"a\"><tr class=\"b\">").candidates,
    content=(
      #|["a", "b"]
    ),
  )
  debug_inspect(
    scan_html("<caption class=\"c\">x</caption>").candidates,
    content=(
      #|["c"]
    ),
  )
  debug_inspect(
    scan_html("<colgroup class=\"d\"><col class=\"e\">").candidates,
    content=(
      #|["d", "e"]
    ),
  )
}

///|
test "scan_html: descends into a nested template" {
  debug_inspect(
    scan_html(
      "<div class=\"outer\"><template><span class=\"inner\">x</span></template></div>",
    ).candidates,
    content=(
      #|["outer", "inner"]
    ),
  )
}

///|
/// A stray `</template>` closes the wrapper early and the rest of the fragment
/// lands in the body, so the walk falls back to the body element.
test "scan_html: stray close tag still finds classes" {
  debug_inspect(
    scan_html("</template><div class=\"btn\">x</div>").candidates,
    content=(
      #|["btn"]
    ),
  )
}

///|
test "scan_html: whitespace, duplicates and document order" {
  debug_inspect(
    scan_html("<div class=\"  a\n\tb\r\nc  \">").candidates,
    content=(
      #|["a", "b", "c"]
    ),
  )
  debug_inspect(
    scan_html("<i class=\"a b\"></i><i class=\"b a c\"></i>").candidates,
    content=(
      #|["a", "b", "c"]
    ),
  )
  debug_inspect(
    scan_html("<i class=\"\"></i><i class=\"   \"></i>").candidates,
    content=(
      #|[]
    ),
  )
  debug_inspect(
    scan_html("<a class=\"one\"><b class=\"two\"><c class=\"three\">").candidates,
    content=(
      #|["one", "two", "three"]
    ),
  )
}

///|
/// Attribute forms a `/class="([^"]*)"/g` regex gets wrong. The junk candidate
/// `([^` in `benchmarks/workloads/margaui/candidates.txt` came from exactly that.
test "scan_html: attribute syntax the regex misses" {
  debug_inspect(
    scan_html("<div class=btn>x</div>").candidates,
    content=(
      #|["btn"]
    ),
  )
  debug_inspect(
    scan_html("<div class='btn btn-sm'>x</div>").candidates,
    content=(
      #|["btn", "btn-sm"]
    ),
  )
  debug_inspect(
    scan_html("<div CLASS=\"btn\">x</div>").candidates,
    content=(
      #|["btn"]
    ),
  )
  debug_inspect(
    scan_html("<div class=\"a&#32;b\">x</div>").candidates,
    content=(
      #|["a", "b"]
    ),
  )
  debug_inspect(
    scan_html("<div class=\"w-1&#47;2\">x</div>").candidates,
    content=(
      #|["w-1/2"]
    ),
  )
  debug_inspect(
    scan_html("<div class=\"a\" class=\"b\">x</div>").candidates,
    content=(
      #|["a"]
    ),
  )
}

///|
/// Raw-text element bodies are text, never markup, so a `class=` inside one is
/// not a candidate.
test "scan_html: script and style bodies are not markup" {
  debug_inspect(
    scan_html(
      "<style>.x{content:\"<div class='fake'>\"}</style><div class=\"real\">",
    ).candidates,
    content=(
      #|["real"]
    ),
  )
  debug_inspect(
    scan_html(
      "<script>let a = 1 < 2; el.innerHTML = '<i class=\"fake\">'</script><b class=\"real\">",
    ).candidates,
    content=(
      #|["real"]
    ),
  )
}

///|
/// Every keystroke feeds the parser an unfinished document. None of these may
/// hang, and none may leak the `</template>` wrapper into the candidate list.
test "scan_html: truncated input" {
  debug_inspect(
    scan_html("<div class=\"bt").candidates,
    content=(
      #|[]
    ),
  )
  debug_inspect(
    scan_html("<div class=").candidates,
    content=(
      #|[]
    ),
  )
  debug_inspect(
    scan_html("<div class=bt").candidates,
    content=(
      #|["bt"]
    ),
  )
  debug_inspect(
    scan_html("<div class=\"btn\" data-x=").candidates,
    content=(
      #|["btn"]
    ),
  )
  debug_inspect(
    scan_html("<div").candidates,
    content=(
      #|[]
    ),
  )
  debug_inspect(
    scan_html("<").candidates,
    content=(
      #|[]
    ),
  )
  debug_inspect(
    scan_html("<!-- unclosed").candidates,
    content=(
      #|[]
    ),
  )
  debug_inspect(
    scan_html("<script>let a = 1 < 2;").candidates,
    content=(
      #|[]
    ),
  )
  debug_inspect(
    scan_html("").candidates,
    content=(
      #|[]
    ),
  )
  debug_inspect(
    scan_html("plain text, no tags").candidates,
    content=(
      #|[]
    ),
  )
}

///|
test "scan_html: foreign content" {
  debug_inspect(
    scan_html("<svg class=\"w-4 h-4\"><path class=\"fill-current\"/></svg>").candidates,
    content=(
      #|["w-4", "h-4", "fill-current"]
    ),
  )
}

///|
/// The walk keeps an explicit stack, so pathological nesting is fine.
test "scan_html: deep nesting" {
  let depth = 5000
  let builder = StringBuilder::new()
  for _ in 0..<depth {
    builder.write_string("<div class=\"deep\">")
  }
  builder.write_string("<span class=\"leaf\">x</span>")
  for _ in 0..<depth {
    builder.write_string("</div>")
  }
  let scan = scan_html(builder.to_string())
  debug_inspect(
    scan.candidates,
    content=(
      #|["deep", "leaf"]
    ),
  )
  debug_inspect(
    scan.elements,
    content=(
      #|5001
    ),
  )
}
