///|
struct SourceSpan {
  start : Int
  end : Int
} derive(Eq, Debug)

///|
#warnings("-unused_constructor")
enum CssNode {
  Declaration(
    name~ : String,
    value~ : String,
    important~ : Bool,
    span~ : SourceSpan
  )
  Rule(selector~ : String, nodes~ : Array[CssNode], span~ : SourceSpan)
  AtRule(
    name~ : String,
    params~ : String,
    nodes~ : Array[CssNode]?,
    span~ : SourceSpan
  )
  Comment(value~ : String, license~ : Bool, span~ : SourceSpan)
  Context(
    values~ : Map[String, String],
    nodes~ : Array[CssNode],
    span~ : SourceSpan
  )
  AtRoot(nodes~ : Array[CssNode], span~ : SourceSpan)
} derive(Eq, Debug)

///|
enum CustomVariantTemplate {
  CustomVariantSelector(String)
  CustomVariantNodes(Array[CssNode])
}

///|
fn render_css_nodes(nodes : ArrayView[CssNode], indent? : Int = 0) -> String {
  let out = StringBuilder()
  for node in nodes {
    render_css_node(node, out, indent~)
  }
  out.to_string()
}

///|
fn write_indent(out : StringBuilder, indent : Int) -> Unit {
  for _ in 0..<indent {
    out.write_string("  ")
  }
}

///|
fn render_css_node(node : CssNode, out : StringBuilder, indent~ : Int) -> Unit {
  match node {
    Declaration(name~, value~, important~, ..) => {
      write_indent(out, indent)
      out.write_string("\{name}: \{value}")
      if important {
        out.write_string(" !important")
      }
      out.write_string(";\n")
    }
    Rule(selector~, nodes~, ..) => {
      write_indent(out, indent)
      out.write_string("\{selector} {\n")
      for child in nodes {
        render_css_node(child, out, indent=indent + 1)
      }
      write_indent(out, indent)
      out.write_string("}\n")
    }
    AtRule(name~, params~, nodes~, ..) =>
      match nodes {
        None => {
          write_indent(out, indent)
          out.write_string(name)
          if params != "" {
            out.write_string(" \{params}")
          }
          out.write_string(";\n")
        }
        Some(children) => {
          write_indent(out, indent)
          out.write_string(name)
          if params != "" {
            out.write_string(" \{params}")
          }
          out.write_string(" {\n")
          for child in children {
            render_css_node(child, out, indent=indent + 1)
          }
          write_indent(out, indent)
          out.write_string("}\n")
        }
      }
    Comment(value~, ..) => {
      write_indent(out, indent)
      out.write_string("/*\{value}*/\n")
    }
    Context(nodes~, ..) =>
      for child in nodes {
        render_css_node(child, out, indent~)
      }
    AtRoot(nodes~, ..) =>
      for child in nodes {
        render_css_node(child, out, indent=0)
      }
  }
}
