///|
/// The candidates found in an HTML fragment, plus what was walked to find them.
priv struct Scan {
  /// Distinct `class` tokens in first-seen order. Order does not affect the
  /// generated CSS (the compiler sorts internally); it only makes the editor's
  /// candidate list stable while typing.
  candidates : Array[String]
  elements : Int
  class_attrs : Int
}

///|
/// Collect the distinct `class` tokens used by an HTML *fragment*.
///
/// The fragment is wrapped in `<template>` before parsing. That is what makes a
/// bare snippet parse the way a browser would parse it inside a page: the
/// spec's "in template" insertion mode re-enters the table insertion modes, so
/// `<tr class="hover">` / `<td class="p-2">` keep their classes instead of being
/// dropped by foster parenting. Parsing the same snippet as a document would
/// silently lose them, and `moonbit-community/html` has no fragment-parsing
/// entry point of its own. See the html5lib `template_588` conformance case.
///
/// Going through a real WHATWG parser rather than a `class="..."` regex also
/// gets unquoted and single-quoted values, uppercase `CLASS`, duplicate
/// attributes and character references (`class="w-1&#47;2"` → `w-1/2`) right,
/// and never mistakes a `<` inside a `<script>` or `<style>` body for a tag.
///
/// The lone `>` before the closing wrapper terminates whatever tag the input
/// stopped inside — every keystroke arrives mid-edit. Without it, `<div class=`
/// leaves the tokenizer in an unquoted attribute value that swallows the
/// wrapper's own `</template` and reports it as a candidate. For input that is
/// already well formed the `>` is just a stray text character.
fn scan_html(html : String) -> Scan {
  let doc = @html5.parse("<body><template>" + html + ">\n</template>")
  let content = match first_template(doc) {
    Some(id) => doc.get_template_content(id)
    None => @html5.NO_NODE
  }
  if content == @html5.NO_NODE {
    return collect_classes(doc, doc.body_element)
  }
  let scan = collect_classes(doc, content)
  // A stray `</template>` in the input closes the wrapper early, leaving it
  // empty and putting the rest of the fragment in the body instead.
  if scan.elements == 0 {
    return collect_classes(doc, doc.body_element)
  }
  scan
}

///|
/// The node id of the wrapper `<template>`, or `None` if it is gone.
///
/// Node ids are indices into `Document::nodes` and the wrapper is created before
/// anything it contains, so the first match in that array is always ours.
fn first_template(doc : @html5.Document) -> Int? {
  for id, node in doc.nodes {
    match node {
      ElementNode(element) =>
        if element.tag_name == "template" {
          return Some(id)
        }
      _ => ()
    }
  }
  None
}

///|
/// Walk the subtree at `root` and collect every `class` token below it.
///
/// The walk keeps its own stack rather than recursing: the input is untrusted
/// and can nest thousands of elements deep. Nested `<template>` elements hold
/// their children in a detached fragment, so their content is pushed explicitly.
fn collect_classes(doc : @html5.Document, root : Int) -> Scan {
  let seen : Map[String, Unit] = Map([])
  let candidates : Array[String] = []
  let stack = [root]
  let mut elements = 0
  let mut class_attrs = 0
  while stack.pop() is Some(id) {
    match doc.get_node(id) {
      Some(ElementNode(element)) => {
        elements += 1
        for attribute in element.attributes {
          if attribute.0 == "class" {
            class_attrs += 1
            push_class_tokens(attribute.1, seen, candidates)
          }
        }
        if element.template_content != @html5.NO_NODE {
          stack.push(element.template_content)
        }
        push_children(stack, element.children)
      }
      Some(DocumentFragmentNode(children~)) | Some(DocumentNode(children~)) =>
        push_children(stack, children)
      _ => ()
    }
  }
  { candidates, elements, class_attrs }
}

///|
/// Push children in reverse so the LIFO stack pops them in document order,
/// which is what makes the candidate list a stable pre-order walk.
fn push_children(stack : Array[Int], children : Array[Int]) -> Unit {
  let count = children.length()
  for offset in 0..<count {
    stack.push(children[count - 1 - offset])
  }
}

///|
/// Split one `class` attribute value on ASCII whitespace, keeping first-seen
/// order and dropping duplicates.
fn push_class_tokens(
  value : String,
  seen : Map[String, Unit],
  out : Array[String],
) -> Unit {
  let length = value.length()
  let mut pos = 0
  while pos < length {
    while pos < length && is_ascii_space(value[pos]) {
      pos += 1
    }
    let start = pos
    while pos < length && !is_ascii_space(value[pos]) {
      pos += 1
    }
    if pos > start {
      let name = value[start:pos].to_owned()
      if !seen.contains(name) {
        seen[name] = ()
        out.push(name)
      }
    }
  }
}

///|
/// The HTML "space characters": space, tab, LF, FF, CR.
fn is_ascii_space(unit : UInt16) -> Bool {
  unit == ' ' ||
  unit == '\t' ||
  unit == '\n' ||
  unit == '\r' ||
  unit == '\u{0C}'
}
