///|
priv struct CssParser {
  input : String
  mut pos : Int
  license_comments : Array[CssNode]
}

///|
fn CssParser::new(input : String) -> CssParser {
  { input, pos: 0, license_comments: [] }
}

///|
fn CssParser::eof(self : CssParser) -> Bool {
  self.pos >= self.input.length()
}

///|
fn CssParser::current(self : CssParser) -> UInt16? {
  if self.eof() {
    None
  } else {
    Some(self.input[self.pos])
  }
}

///|
fn is_css_whitespace(c : UInt16) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t' || c == '\u000c'
}

///|
/// A "plain" value char is one that `read_until_top_level` copies through
/// verbatim: not an escape, quote, comment-introducing `/`, bracket/paren (those
/// need depth tracking), whitespace (collapsed to single spaces), or a terminal
/// (may end the value). Runs of these are copied in one `write_view` instead of
/// one code unit at a time — the parser's hottest inner loop (see the tokenizers
/// in mizchi/css and moonbitlang/parser, which likewise scan a run then copy once).
fn is_plain_value_char(c : UInt16, terminals : ArrayView[UInt16]) -> Bool {
  if c == '\\' ||
    c == '\'' ||
    c == '"' ||
    c == '/' ||
    c == '(' ||
    c == ')' ||
    c == '[' ||
    c == ']' {
    return false
  }
  if is_css_whitespace(c) {
    return false
  }
  for t in terminals {
    if c == t {
      return false
    }
  }
  true
}

///|
fn CssParser::skip_whitespace(self : CssParser) -> Unit {
  while self.current() is Some(c) && is_css_whitespace(c) {
    self.pos += 1
  }
}

///|
fn CssParser::error(self : CssParser, message : String) -> CompileError {
  InvalidCss("\{message} at offset \{self.pos}")
}

///|
fn CssParser::consume_string(
  self : CssParser,
  quote : UInt16,
) -> Unit raise CompileError {
  self.pos += 1
  while self.current() is Some(c) {
    if c == '\\' {
      self.pos += 1
      if !self.eof() {
        self.pos += 1
      }
    } else if c == quote {
      self.pos += 1
      return
    } else if c == '\n' || c == '\r' {
      raise self.error("Unterminated string")
    } else {
      self.pos += 1
    }
  }
  raise self.error("Unterminated string")
}

///|
fn CssParser::consume_comment(self : CssParser) -> CssNode raise CompileError {
  let start = self.pos
  self.pos += 2
  let value_start = self.pos
  while self.pos + 1 < self.input.length() {
    if self.input[self.pos] == '*' && self.input[self.pos + 1] == '/' {
      let value = self.input[value_start:self.pos].to_owned()
      self.pos += 2
      return Comment(value~, license=value.has_prefix("!"), span={
        start,
        end: self.pos,
      })
    }
    self.pos += 1
  }
  raise self.error("Unterminated comment")
}

///|
/// Materialize the token accumulated by `read_until_top_level`.
///
/// In the common case nothing was ever copied: the token is the source range
/// `[content_start, content_end)` and this is its only copy.
fn CssParser::finish_token(
  self : CssParser,
  output : StringBuilder,
  verbatim : Bool,
  content_start : Int,
  content_end : Int,
) -> String {
  if verbatim {
    if content_start < 0 {
      ""
    } else {
      trim(self.input[content_start:content_end].to_owned())
    }
  } else {
    trim(output.to_string())
  }
}

///|
fn CssParser::read_until_top_level(
  self : CssParser,
  terminals : ArrayView[UInt16],
) -> (String, UInt16?) raise CompileError {
  // Almost every token is exactly a slice of the source. Only two things make
  // the result differ from `input[content_start:content_end]`: a comment, which
  // is dropped from the output, and a whitespace run that is not already a
  // single space, which is collapsed to one. Until one of those turns up the
  // token is just a pair of offsets — no builder is filled and nothing is
  // copied, where before every token was copied into the `StringBuilder` and
  // then copied a second time by `to_string()`. On the first such event the
  // offsets are flushed into the builder and the original path takes over.
  let output = StringBuilder()
  let mut verbatim = true
  let mut content_start = -1
  let mut content_end = -1
  let mut has_output = false
  let mut pending_space = false
  // Whether the pending whitespace is a single space already sitting between
  // `content_end` and whatever comes next, so extending the slice reproduces it.
  let mut pending_space_verbatim = false
  let mut parens = 0
  let mut brackets = 0
  let len = self.input.length()
  while self.pos < len {
    let c = self.input[self.pos]
    let run_start = self.pos
    if is_plain_value_char(c, terminals) {
      // Fast path: take a maximal run of plain content chars at once rather
      // than one code unit per iteration.
      self.pos += 1
      while self.pos < len &&
            is_plain_value_char(self.input[self.pos], terminals) {
        self.pos += 1
      }
    } else if c == '\\' {
      self.pos += 1
      if !self.eof() {
        self.pos += 1
      }
    } else if c == '\'' || c == '"' {
      self.consume_string(c)
    } else if c == '/' && self.pos + 1 < len && self.input[self.pos + 1] == '*' {
      // A comment is dropped, so the source slice can no longer stand in for
      // the token.
      if verbatim {
        if content_start >= 0 {
          output.write_view(self.input[content_start:content_end])
        }
        verbatim = false
      }
      let comment = self.consume_comment()
      if comment is Comment(license=true, ..) {
        self.license_comments.push(comment)
      }
      continue
    } else if is_css_whitespace(c) {
      self.skip_whitespace()
      pending_space = has_output
      pending_space_verbatim = self.pos - run_start == 1 &&
        self.input[run_start] == ' '
      continue
    } else {
      match c {
        '(' => parens += 1
        ')' => {
          if parens == 0 {
            raise self.error("Unexpected closing parenthesis")
          }
          parens -= 1
        }
        '[' => brackets += 1
        ']' => {
          if brackets == 0 {
            raise self.error("Unexpected closing bracket")
          }
          brackets -= 1
        }
        _ => ()
      }
      if parens == 0 && brackets == 0 && terminals.contains(c) {
        return (
          self.finish_token(output, verbatim, content_start, content_end),
          Some(c),
        )
      }
      self.pos += 1
    }
    // Emit `input[run_start:self.pos]`, either by extending the slice or, once
    // the slice has been given up, by writing it to the builder.
    if verbatim && pending_space && !pending_space_verbatim {
      if content_start >= 0 {
        output.write_view(self.input[content_start:content_end])
      }
      verbatim = false
    }
    if verbatim {
      if content_start < 0 {
        content_start = run_start
      }
      content_end = self.pos
      pending_space = false
    } else {
      if pending_space {
        output.write_char(' ')
        pending_space = false
      }
      output.write_view(self.input[run_start:self.pos])
    }
    has_output = true
  }
  if parens != 0 || brackets != 0 {
    raise self.error("Unbalanced value")
  }
  (self.finish_token(output, verbatim, content_start, content_end), None)
}

///|
fn split_important(value : String) -> (String, Bool) {
  let trimmed = trim(value)
  if trimmed.has_suffix("!important") {
    (trim(trimmed[:trimmed.length() - 10].to_owned()), true)
  } else {
    (trimmed, false)
  }
}

///|
fn CssParser::parse_custom_property(
  self : CssParser,
) -> CssNode raise CompileError {
  let start = self.pos
  let mut colon = -1
  let mut parens = 0
  let mut brackets = 0
  let mut braces = 0
  while self.current() is Some(current) {
    if current == '\\' {
      self.pos += 1
      if !self.eof() {
        self.pos += 1
      }
      continue
    }
    if current == '\'' || current == '"' {
      self.consume_string(current)
      continue
    }
    if current == '/' &&
      self.pos + 1 < self.input.length() &&
      self.input[self.pos + 1] == '*' {
      ignore(self.consume_comment())
      continue
    }
    if colon < 0 && current == ':' {
      colon = self.pos
    } else if colon >= 0 {
      match current {
        '(' => parens += 1
        ')' => if parens > 0 { parens -= 1 }
        '[' => brackets += 1
        ']' => if brackets > 0 { brackets -= 1 }
        '{' => braces += 1
        '}' =>
          if braces > 0 {
            braces -= 1
          } else if parens == 0 && brackets == 0 {
            break
          }
        ';' => if parens == 0 && brackets == 0 && braces == 0 { break }
        _ => ()
      }
    }
    self.pos += 1
  }
  if colon < 0 {
    raise self.error("Invalid custom property, expected a value")
  }
  let name = trim(self.input[start:colon].to_owned())
  let (value, important) = split_important(
    self.input[colon + 1:self.pos].to_owned(),
  )
  if self.current() is Some(';') {
    self.pos += 1
  }
  Declaration(name~, value~, important~, span={ start, end: self.pos })
}

///|
fn CssParser::parse_statement(self : CssParser) -> CssNode raise CompileError {
  let start = self.pos
  if self.pos + 1 < self.input.length() &&
    self.input[self.pos] == '-' &&
    self.input[self.pos + 1] == '-' {
    self.parse_custom_property()
  } else if self.current() is Some('@') {
    let (header, terminal) = self.read_until_top_level([';', '{', '}'])
    let parts = header.split(" ")
    let name = parts.next().unwrap_or("").to_owned()
    let params = trim(header[name.length():].to_owned())
    match terminal {
      Some(';') => {
        self.pos += 1
        AtRule(name~, params~, nodes=None, span={ start, end: self.pos })
      }
      Some('{') => {
        self.pos += 1
        let children = self.parse_nodes(stop_at_closing_brace=true)
        AtRule(name~, params~, nodes=Some(children), span={
          start,
          end: self.pos,
        })
      }
      Some('}') =>
        AtRule(name~, params~, nodes=None, span={ start, end: self.pos })
      _ => AtRule(name~, params~, nodes=None, span={ start, end: self.pos })
    }
  } else {
    let (statement, terminal) = self.read_until_top_level([';', '{', '}'])
    match terminal {
      Some('{') => {
        if statement == "" {
          raise self.error("Expected selector")
        }
        self.pos += 1
        let children = self.parse_nodes(stop_at_closing_brace=true)
        Rule(selector=statement, nodes=children, span={ start, end: self.pos })
      }
      Some(';') => {
        guard statement.split_once(":") is Some((name, raw_value)) else {
          raise self.error("Expected declaration")
        }
        self.pos += 1
        let (value, important) = split_important(raw_value.to_owned())
        Declaration(name=trim(name.to_owned()), value~, important~, span={
          start,
          end: self.pos,
        })
      }
      Some('}') | None =>
        match statement.split_once(":") {
          Some((name, raw_value)) => {
            let (value, important) = split_important(raw_value.to_owned())
            Declaration(name=trim(name.to_owned()), value~, important~, span={
              start,
              end: self.pos,
            })
          }
          None => raise self.error("Expected declaration")
        }
      _ => raise self.error("Unexpected statement")
    }
  }
}

///|
fn CssParser::parse_nodes(
  self : CssParser,
  stop_at_closing_brace~ : Bool,
) -> Array[CssNode] raise CompileError {
  let nodes : Array[CssNode] = []
  while !self.eof() {
    self.skip_whitespace()
    if self.eof() {
      break
    }
    if self.current() is Some('}') {
      if !stop_at_closing_brace {
        raise self.error("Unexpected closing brace")
      }
      self.pos += 1
      return nodes
    }
    if self.current() is Some(';') {
      self.pos += 1
      continue
    }
    if self.current() is Some('/') &&
      self.pos + 1 < self.input.length() &&
      self.input[self.pos + 1] == '*' {
      let comment = self.consume_comment()
      if comment is Comment(license=true, ..) {
        self.license_comments.push(comment)
      }
    } else {
      nodes.push(self.parse_statement())
    }
  }
  if stop_at_closing_brace {
    raise self.error("Unclosed block")
  }
  nodes
}

///|
fn parse_css(input : String) -> Array[CssNode] raise CompileError {
  let normalized = if input.has_prefix("\uFEFF") {
    " \{input[1:]}"
  } else {
    input
  }
  let parser = CssParser::new(normalized)
  let nodes = parser.parse_nodes(stop_at_closing_brace=false)
  parser.license_comments + nodes
}
