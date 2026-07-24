///|
#warnings("-unused_field")
priv struct AttributeSelector {
  attribute : String
  operator : String?
  quote : String?
  value : String?
  sensitivity : String?
}

///|
fn is_attribute_whitespace(character : UInt16) -> Bool {
  character == ' ' ||
  character == '\t' ||
  character == '\n' ||
  character == '\r'
}

///|
fn is_attribute_name_character(character : UInt16) -> Bool {
  (character >= 'a' && character <= 'z') ||
  (character >= 'A' && character <= 'Z') ||
  (character >= '0' && character <= '9') ||
  character == '-' ||
  character == '_' ||
  character.to_int() >= 128
}

///|
fn parse_attribute_selector(input : String) -> AttributeSelector? {
  if input.length() < 3 || input[0] != '[' || input[input.length() - 1] != ']' {
    return None
  }
  let end = input.length() - 1
  let mut index = 1
  while index < end && is_attribute_whitespace(input[index]) {
    index += 1
  }
  let name_start = index
  while index < end {
    if input[index] == '\\' {
      if index + 1 >= end {
        return None
      }
      index += 2
    } else if is_attribute_name_character(input[index]) {
      index += 1
    } else {
      break
    }
  }
  if index == name_start {
    return None
  }
  let attribute = input[name_start:index].to_owned()
  while index < end && is_attribute_whitespace(input[index]) {
    index += 1
  }
  if index == end {
    return Some({
      attribute,
      operator: None,
      quote: None,
      value: None,
      sensitivity: None,
    })
  }
  let operator = if input[index] == '=' {
    index += 1
    "="
  } else if index + 1 < end &&
    (
      input[index] == '~' ||
      input[index] == '|' ||
      input[index] == '^' ||
      input[index] == '$' ||
      input[index] == '*'
    ) &&
    input[index + 1] == '=' {
    let result = input[index:index + 2].to_owned()
    index += 2
    result
  } else {
    return None
  }
  while index < end && is_attribute_whitespace(input[index]) {
    index += 1
  }
  if index == end {
    return None
  }
  let mut quote : String? = None
  let mut value = ""
  if input[index] == '\'' || input[index] == '"' {
    let expected = input[index]
    quote = Some(input[index:index + 1].to_owned())
    index += 1
    let value_start = index
    let mut closing = -1
    while index < end {
      if input[index] == '\\' {
        index += 2
      } else if input[index] == expected {
        closing = index
        break
      } else {
        index += 1
      }
    }
    if closing < 0 {
      return None
    }
    value = input[value_start:closing].to_owned()
    index = closing + 1
  } else {
    let value_start = index
    while index < end && !is_attribute_whitespace(input[index]) {
      index += 1
    }
    value = input[value_start:index].to_owned()
  }
  if value == "" {
    return None
  }
  while index < end && is_attribute_whitespace(input[index]) {
    index += 1
  }
  let mut sensitivity : String? = None
  if index < end {
    let flag = input[index]
    if flag == 'i' || flag == 'I' {
      sensitivity = Some("i")
    } else if flag == 's' || flag == 'S' {
      sensitivity = Some("s")
    } else {
      return None
    }
    index += 1
    while index < end && is_attribute_whitespace(input[index]) {
      index += 1
    }
  }
  if index != end {
    return None
  }
  Some({
    attribute,
    operator: Some(operator),
    quote,
    value: Some(value),
    sensitivity,
  })
}
