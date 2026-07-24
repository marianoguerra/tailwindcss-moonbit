///|
#warnings("-unused_field")
priv enum CandidateModifier {
  NamedModifier(value~ : String, source~ : String)
  ArbitraryModifier(value~ : String, source~ : String)
}

///|
#warnings("-unused_constructor")
priv enum CandidateValue {
  NamedValue(value~ : String, fraction~ : String?)
  ArbitraryValue(data_type~ : String?, value~ : String)
}

///|
#warnings("-unused_field")
priv enum CandidateForm {
  StaticCandidate(root~ : String)
  FunctionalCandidate(
    root~ : String,
    value~ : CandidateValue?,
    source~ : String
  )
  ArbitraryPropertyCandidate(
    property~ : String,
    value~ : String,
    source~ : String
  )
}

///|
#warnings("-unused_field")
priv enum CandidateVariant {
  ArbitraryVariant(selector~ : String, relative~ : Bool, source~ : String)
  StaticVariant(root~ : String, source~ : String)
  FunctionalVariant(
    root~ : String,
    value~ : String?,
    modifier~ : CandidateModifier?,
    source~ : String
  )
  CompoundVariant(
    root~ : String,
    modifier~ : CandidateModifier?,
    variant~ : CandidateVariant,
    source~ : String
  )
}

///|
#warnings("-unused_field")
priv struct ParsedCandidate {
  form : CandidateForm
  negative : Bool
  important : Bool
  modifier : CandidateModifier?
  variants : Array[CandidateVariant]
  raw : String
}

///|
fn split_modifier(input : String) -> (String, String?) {
  let mut depth = 0
  for i in 0..<input.length() {
    match input[i] {
      '[' | '(' => depth += 1
      ']' | ')' => depth -= 1
      '/' =>
        if depth == 0 {
          return (input[:i].to_owned(), Some(input[i + 1:].to_owned()))
        }
      _ => ()
    }
  }
  (input, None)
}

///|
fn is_named_candidate_part(input : String) -> Bool {
  if input == "" {
    return false
  }
  for character in input {
    if !((character >= 'a' && character <= 'z') ||
      (character >= 'A' && character <= 'Z') ||
      (character >= '0' && character <= '9') ||
      character == '_' ||
      character == '.' ||
      character == '%' ||
      character == '-') {
      return false
    }
  }
  true
}

///|
fn modifier_value(modifier : String) -> String? {
  if modifier.has_prefix("[") && modifier.has_suffix("]") {
    let value = decode_arbitrary(modifier[1:modifier.length() - 1].to_owned())
    if trim(value) == "" || !is_valid_arbitrary(value) {
      None
    } else {
      Some(value)
    }
  } else if modifier.has_prefix("(") && modifier.has_suffix(")") {
    let variable = modifier[1:modifier.length() - 1].to_owned()
    if !variable.has_prefix("--") || !is_valid_arbitrary(variable) {
      None
    } else {
      Some("var(\{decode_arbitrary(variable)})")
    }
  } else if is_named_candidate_part(modifier) {
    Some(modifier)
  } else {
    None
  }
}

///|
fn parse_candidate_modifier(modifier : String) -> CandidateModifier? {
  guard modifier_value(modifier) is Some(value) else { return None }
  if modifier.has_prefix("[") || modifier.has_prefix("(") {
    Some(ArbitraryModifier(value~, source=modifier))
  } else {
    Some(NamedModifier(value~, source=modifier))
  }
}

///|
fn CandidateModifier::source(self : CandidateModifier) -> String {
  match self {
    NamedModifier(source~, ..) | ArbitraryModifier(source~, ..) => source
  }
}

///|
fn parse_candidate_variant(source : String) -> CandidateVariant? {
  if source.has_prefix("[") {
    if !source.has_suffix("]") || source.length() < 3 {
      return None
    }
    let selector = decode_arbitrary(source[1:source.length() - 1].to_owned())
    if trim(selector) == "" || !is_valid_arbitrary(selector) {
      return None
    }
    let relative = selector.has_prefix(">") ||
      selector.has_prefix("+") ||
      selector.has_prefix("~")
    return Some(ArbitraryVariant(selector~, relative~, source~))
  }
  let (without_modifier, raw_modifier) = split_modifier(source)
  let modifier = match raw_modifier {
    Some(value) =>
      match parse_candidate_modifier(value) {
        Some(value) => Some(value)
        None => return None
      }
    None => None
  }
  let compound_roots = ["group", "peer", "has", "not", "in"]
  for root in compound_roots {
    let marker = "\{root}-"
    if without_modifier.has_prefix(marker) {
      let inner = without_modifier[marker.length():].to_owned()
      guard parse_candidate_variant(inner) is Some(variant) else { return None }
      let (modifier, variant) = if (
          root == "not" || root == "has" || root == "in"
        ) &&
        modifier is Some(forwarded) {
        match variant {
          CompoundVariant(
            root=inner_root,
            modifier=None,
            variant=inner_variant,
            source=inner_source
          ) =>
            (
              None,
              CompoundVariant(
                root=inner_root,
                modifier=Some(forwarded),
                variant=inner_variant,
                source=inner_source,
              ),
            )
          _ => (modifier, variant)
        }
      } else {
        (modifier, variant)
      }
      return Some(CompoundVariant(root~, modifier~, variant~, source~))
    }
  }
  let functional_roots = [
    "aria", "data", "nth", "nth-last", "supports", "min", "max",
  ]
  for root in functional_roots {
    let marker = "\{root}-"
    if without_modifier.has_prefix(marker) {
      let value = without_modifier[marker.length():].to_owned()
      if value == "" {
        return None
      }
      return Some(
        FunctionalVariant(root~, value=Some(value), modifier~, source~),
      )
    }
  }
  if without_modifier.has_prefix("@") {
    let root = if without_modifier.has_prefix("@min-") {
      "@min"
    } else if without_modifier.has_prefix("@max-") {
      "@max"
    } else {
      "@"
    }
    let value = if root == "@" {
      without_modifier[1:].to_owned()
    } else {
      without_modifier[root.length() + 1:].to_owned()
    }
    return Some(FunctionalVariant(root~, value=Some(value), modifier~, source~))
  }
  if modifier is Some(_) {
    return None
  }
  Some(StaticVariant(root=without_modifier, source~))
}

///|
fn CandidateVariant::source(self : CandidateVariant) -> String {
  match self {
    ArbitraryVariant(source~, ..)
    | StaticVariant(source~, ..)
    | FunctionalVariant(source~, ..)
    | CompoundVariant(source~, ..) => source
  }
}

///|
fn encode_arbitrary_for_candidate(value : String) -> String {
  let output = StringBuilder()
  for character in trim(value) {
    if character == ' ' {
      output.write_char('_')
    } else if character == '_' {
      output.write_string("\\_")
    } else {
      output.write_char(character)
    }
  }
  output.to_string()
}

///|
fn CandidateVariant::canonical(self : CandidateVariant) -> String {
  match self {
    ArbitraryVariant(selector~, ..) => {
      let selector = trim(selector)
      let simplified = if selector.has_prefix("&:is(") &&
        selector.has_suffix(")") {
        selector[5:selector.length() - 1].to_owned()
      } else {
        selector
      }
      "[\{encode_arbitrary_for_candidate(simplified)}]"
    }
    StaticVariant(root~, ..) => root
    FunctionalVariant(source~, ..) => source
    CompoundVariant(root~, modifier~, variant~, ..) => {
      let output = StringBuilder()
      output.write_string("\{root}-\{variant.canonical()}")
      match modifier {
        Some(modifier) => output.write_string("/\{modifier.source()}")
        None => ()
      }
      output.to_string()
    }
  }
}

///|
fn validate_arbitrary_candidate_base(base : String) -> Bool {
  if base.has_prefix("[") {
    if !base.has_suffix("]") || base.length() < 4 {
      return false
    }
    let inner = base[1:base.length() - 1].to_owned()
    guard inner.split_once(":") is Some((property, raw_value)) else {
      return false
    }
    if property == "" || raw_value == "" {
      return false
    }
    let first = property[0]
    if first != '-' && !(first >= 'a' && first <= 'z') {
      return false
    }
    let value = decode_arbitrary(raw_value.to_owned())
    return trim(value) != "" && is_valid_arbitrary(value)
  }
  let arbitrary_start = match base.find("-[") {
    Some(index) => Some((index, true))
    None =>
      match base.find("-(") {
        Some(index) => Some((index, false))
        None => None
      }
  }
  match arbitrary_start {
    None => true
    Some((index, brackets)) => {
      if index == 0 ||
        (brackets && base[base.length() - 1] != ']') ||
        (!brackets && base[base.length() - 1] != ')') {
        return false
      }
      let raw_value = base[index + 2:base.length() - 1].to_owned()
      if !brackets {
        let variable = match raw_value.split_once(":") {
          Some((_, value)) => value.to_owned()
          None => raw_value
        }
        if !variable.has_prefix("--") {
          return false
        }
      }
      let value = decode_arbitrary(raw_value)
      trim(value) != "" && is_valid_arbitrary(value)
    }
  }
}

///|
fn parse_candidate_form(
  base : String,
  modifier : CandidateModifier?,
) -> CandidateForm? {
  if base.has_prefix("[") {
    let inner = base[1:base.length() - 1].to_owned()
    guard inner.split_once(":") is Some((property, raw_value)) else {
      return None
    }
    return Some(
      ArbitraryPropertyCandidate(
        property=property.to_owned(),
        value=decode_arbitrary(raw_value.to_owned()),
        source=base,
      ),
    )
  }
  let arbitrary_index = match base.find("-[") {
    Some(index) => Some((index, true))
    None =>
      match base.find("-(") {
        Some(index) => Some((index, false))
        None => None
      }
  }
  match arbitrary_index {
    Some((index, brackets)) => {
      let root = base[:index].to_owned()
      let raw_value = base[index + 2:base.length() - 1].to_owned()
      let (data_type, value) = if !brackets {
        match raw_value.split_once(":") {
          Some((hint, variable)) =>
            (
              Some(hint.to_owned()),
              "var(\{decode_arbitrary(variable.to_owned())})",
            )
          None => (None, "var(\{decode_arbitrary(raw_value)})")
        }
      } else {
        let decoded = decode_arbitrary(raw_value)
        match decoded.split_once(":") {
          Some((hint, value)) if is_named_candidate_part(hint.to_owned()) =>
            (Some(hint.to_owned()), value.to_owned())
          _ => (None, decoded)
        }
      }
      Some(
        FunctionalCandidate(
          root~,
          value=Some(ArbitraryValue(data_type~, value~)),
          source=base,
        ),
      )
    }
    None =>
      if static_utility(base) is Some(_) && modifier is None {
        Some(StaticCandidate(root=base))
      } else {
        match base.rev_split_once("-") {
          Some((root, value)) if root != "" && value != "" => {
            let fraction = match modifier {
              Some(NamedModifier(value=modifier, ..)) =>
                Some("\{value}/\{modifier}")
              _ => None
            }
            Some(
              FunctionalCandidate(
                root=root.to_owned(),
                value=Some(NamedValue(value=value.to_owned(), fraction~)),
                source=base,
              ),
            )
          }
          _ => Some(FunctionalCandidate(root=base, value=None, source=base))
        }
      }
  }
}

///|
fn parse_candidate(raw : String) -> ParsedCandidate? {
  if raw == "" {
    return None
  }
  let parts = split_variants(raw)
  guard parts.pop() is Some(raw_base) && raw_base != "" else { return None }
  let important = raw_base.has_suffix("!") || raw_base.has_prefix("!")
  let without_important = if important {
    if raw_base.has_suffix("!") {
      raw_base[:raw_base.length() - 1].to_owned()
    } else {
      raw_base[1:].to_owned()
    }
  } else {
    raw_base
  }
  let negative = without_important.has_prefix("-")
  let positive = if negative {
    without_important[1:].to_owned()
  } else {
    without_important
  }
  let (base, modifier) = split_modifier(positive)
  let parsed_modifier = match modifier {
    Some(value) =>
      match parse_candidate_modifier(value) {
        Some(value) => Some(value)
        None => return None
      }
    None => None
  }
  if base == "" ||
    base.has_suffix("-") ||
    modifier == Some("") ||
    !validate_arbitrary_candidate_base(base) ||
    (negative && base.has_prefix("[")) ||
    parts.any(fn(variant) { variant == "" }) {
    return None
  }
  let variants : Array[CandidateVariant] = []
  for part in parts {
    guard parse_candidate_variant(part) is Some(variant) else { return None }
    variants.push(variant)
  }
  guard parse_candidate_form(base, parsed_modifier) is Some(form) else {
    return None
  }
  Some({ form, negative, important, modifier: parsed_modifier, variants, raw })
}

///|
fn ParsedCandidate::base(self : ParsedCandidate) -> String {
  match self.form {
    StaticCandidate(root~) => root
    FunctionalCandidate(source~, ..)
    | ArbitraryPropertyCandidate(source~, ..) => source
  }
}

///|
fn ParsedCandidate::modifier_source(self : ParsedCandidate) -> String? {
  self.modifier.map(fn(modifier) { modifier.source() })
}

///|
#warnings("-unused_value")
fn print_candidate(candidate : ParsedCandidate) -> String {
  let output = StringBuilder()
  for variant in candidate.variants {
    output.write_string(variant.canonical())
    output.write_char(':')
  }
  if candidate.negative {
    output.write_char('-')
  }
  output.write_string(candidate.base())
  match candidate.modifier {
    Some(modifier) => output.write_string("/\{modifier.source()}")
    None => ()
  }
  if candidate.important {
    output.write_char('!')
  }
  output.to_string()
}
