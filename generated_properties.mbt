///|
priv struct GeneratedPropertySpec {
  name : String
  syntax : String
  initial : String?
  initial_before_inherits : Bool
}

///|
/// A block of `@property` registrations that upstream emits as one `at-root`
/// node.
///
/// `triggers` are the declaration fragments that show the owning utility ran.
/// Membership in a block is all or nothing: registering one member registers
/// every member, in the declared order.
priv struct GeneratedPropertyBlock {
  triggers : Array[String]
  members : Array[GeneratedPropertySpec]
}

///|
fn property_spec(
  name : String,
  syntax : String,
  initial? : String,
  initial_before_inherits? : Bool = false,
) -> GeneratedPropertySpec {
  { name, syntax, initial, initial_before_inherits }
}

///|
fn declaration_triggers(names : ArrayView[String]) -> Array[String] {
  names.map(fn(name) { "\{name}:" })
}

///|
fn generated_property_blocks() -> Array[GeneratedPropertyBlock] {
  [
    {
      triggers: ["--tw-border-spacing-x:", "--tw-border-spacing-y:"],
      members: [
        property_spec("--tw-border-spacing-x", "<length>", initial="0"),
        property_spec("--tw-border-spacing-y", "<length>", initial="0"),
      ],
    },
    {
      triggers: ["var(--tw-border-style"],
      members: [property_spec("--tw-border-style", "*", initial="solid")],
    },
    {
      triggers: ["--tw-space-x-reverse:"],
      members: [property_spec("--tw-space-x-reverse", "*", initial="0")],
    },
    {
      triggers: ["--tw-space-y-reverse:"],
      members: [property_spec("--tw-space-y-reverse", "*", initial="0")],
    },
    {
      triggers: ["--tw-divide-x-reverse:"],
      members: [property_spec("--tw-divide-x-reverse", "*", initial="0")],
    },
    {
      triggers: ["--tw-divide-y-reverse:"],
      members: [property_spec("--tw-divide-y-reverse", "*", initial="0")],
    },
    {
      triggers: ["var(--tw-outline-style"],
      members: [property_spec("--tw-outline-style", "*", initial="solid")],
    },
    {
      triggers: ["--tw-leading:"],
      members: [property_spec("--tw-leading", "*")],
    },
    {
      triggers: ["--tw-font-weight:"],
      members: [property_spec("--tw-font-weight", "*")],
    },
    {
      triggers: [
        "--tw-translate-x:", "--tw-translate-y:", "--tw-translate-z:", "var(--tw-translate-",
      ],
      members: [
        property_spec("--tw-translate-x", "*", initial="0"),
        property_spec("--tw-translate-y", "*", initial="0"),
        property_spec("--tw-translate-z", "*", initial="0"),
      ],
    },
    {
      triggers: [
        "--tw-scale-x:", "--tw-scale-y:", "--tw-scale-z:", "var(--tw-scale-",
      ],
      members: [
        property_spec("--tw-scale-x", "*", initial="1"),
        property_spec("--tw-scale-y", "*", initial="1"),
        property_spec("--tw-scale-z", "*", initial="1"),
      ],
    },
    {
      triggers: [
        "--tw-rotate-x:", "--tw-rotate-y:", "--tw-rotate-z:", "--tw-skew-x:", "--tw-skew-y:",
        "var(--tw-rotate-", "var(--tw-skew-",
      ],
      members: [
        property_spec("--tw-rotate-x", "*"),
        property_spec("--tw-rotate-y", "*"),
        property_spec("--tw-rotate-z", "*"),
        property_spec("--tw-skew-x", "*"),
        property_spec("--tw-skew-y", "*"),
      ],
    },
    {
      triggers: [
        "--tw-pan-x:", "--tw-pan-y:", "--tw-pinch-zoom:", "var(--tw-pan-", "var(--tw-pinch-zoom",
      ],
      members: [
        property_spec("--tw-pan-x", "*"),
        property_spec("--tw-pan-y", "*"),
        property_spec("--tw-pinch-zoom", "*"),
      ],
    },
    {
      triggers: [
        "--tw-scroll-snap-strictness:", "var(--tw-scroll-snap-strictness",
      ],
      members: [
        property_spec("--tw-scroll-snap-strictness", "*", initial="proximity"),
      ],
    },
    {
      triggers: declaration_triggers([
        "--tw-gradient-from", "--tw-gradient-via", "--tw-gradient-to", "--tw-gradient-stops",
        "--tw-gradient-via-stops", "--tw-gradient-from-position", "--tw-gradient-via-position",
        "--tw-gradient-to-position",
      ]),
      members: [
        property_spec("--tw-gradient-position", "*"),
        property_spec("--tw-gradient-from", "<color>", initial="#0000"),
        property_spec("--tw-gradient-via", "<color>", initial="#0000"),
        property_spec("--tw-gradient-to", "<color>", initial="#0000"),
        property_spec("--tw-gradient-stops", "*"),
        property_spec("--tw-gradient-via-stops", "*"),
        property_spec(
          "--tw-gradient-from-position",
          "<length-percentage>",
          initial="0%",
        ),
        property_spec(
          "--tw-gradient-via-position",
          "<length-percentage>",
          initial="50%",
        ),
        property_spec(
          "--tw-gradient-to-position",
          "<length-percentage>",
          initial="100%",
        ),
      ],
    },
    {
      triggers: declaration_triggers([
        "--tw-shadow", "--tw-shadow-color", "--tw-inset-shadow", "--tw-inset-shadow-color",
        "--tw-ring-shadow", "--tw-inset-ring-shadow", "--tw-ring-inset",
      ]),
      members: [
        property_spec("--tw-shadow", "*", initial="0 0 #0000"),
        property_spec("--tw-shadow-color", "*"),
        property_spec("--tw-shadow-alpha", "<percentage>", initial="100%"),
        property_spec("--tw-inset-shadow", "*", initial="0 0 #0000"),
        property_spec("--tw-inset-shadow-color", "*"),
        property_spec("--tw-inset-shadow-alpha", "<percentage>", initial="100%"),
        property_spec("--tw-ring-color", "*"),
        property_spec("--tw-ring-shadow", "*", initial="0 0 #0000"),
        property_spec("--tw-inset-ring-color", "*"),
        property_spec("--tw-inset-ring-shadow", "*", initial="0 0 #0000"),
        property_spec("--tw-ring-inset", "*"),
        property_spec("--tw-ring-offset-width", "<length>", initial="0px"),
        property_spec("--tw-ring-offset-color", "*", initial="#fff"),
        property_spec("--tw-ring-offset-shadow", "*", initial="0 0 #0000"),
      ],
    },
    {
      triggers: ["filter: var(--tw-blur"],
      members: [
        property_spec("--tw-blur", "*"),
        property_spec("--tw-brightness", "*"),
        property_spec("--tw-contrast", "*"),
        property_spec("--tw-grayscale", "*"),
        property_spec("--tw-hue-rotate", "*"),
        property_spec("--tw-invert", "*"),
        property_spec("--tw-opacity", "*"),
        property_spec("--tw-saturate", "*"),
        property_spec("--tw-sepia", "*"),
        property_spec("--tw-drop-shadow", "*"),
        property_spec("--tw-drop-shadow-color", "*"),
        property_spec("--tw-drop-shadow-alpha", "<percentage>", initial="100%"),
        property_spec("--tw-drop-shadow-size", "*"),
      ],
    },
    {
      triggers: ["backdrop-filter: var(--tw-backdrop-blur"],
      members: [
        property_spec("--tw-backdrop-blur", "*"),
        property_spec("--tw-backdrop-brightness", "*"),
        property_spec("--tw-backdrop-contrast", "*"),
        property_spec("--tw-backdrop-grayscale", "*"),
        property_spec("--tw-backdrop-hue-rotate", "*"),
        property_spec("--tw-backdrop-invert", "*"),
        property_spec("--tw-backdrop-opacity", "*"),
        property_spec("--tw-backdrop-saturate", "*"),
        property_spec("--tw-backdrop-sepia", "*"),
      ],
    },
    {
      triggers: ["--tw-duration:"],
      members: [property_spec("--tw-duration", "*")],
    },
    { triggers: ["--tw-ease:"], members: [property_spec("--tw-ease", "*")] },
    {
      // Trigger on the utility's own custom property rather than a plain
      // `text-shadow:` declaration, so author `text-shadow` rules don't register
      // these (upstream registers them only for the `text-shadow-*` utility).
      triggers: ["--tw-text-shadow-color"],
      members: [
        property_spec("--tw-text-shadow-color", "*"),
        property_spec("--tw-text-shadow-alpha", "<percentage>", initial="100%"),
      ],
    },
    {
      triggers: ["--tw-tracking:"],
      members: [property_spec("--tw-tracking", "*")],
    },
    {
      triggers: declaration_triggers([
        "--tw-ordinal", "--tw-slashed-zero", "--tw-numeric-figure", "--tw-numeric-spacing",
        "--tw-numeric-fraction",
      ]),
      members: [
        property_spec("--tw-ordinal", "*"),
        property_spec("--tw-slashed-zero", "*"),
        property_spec("--tw-numeric-figure", "*"),
        property_spec("--tw-numeric-spacing", "*"),
        property_spec("--tw-numeric-fraction", "*"),
      ],
    },
    {
      // `content-none` sets the property without reading it back and registers
      // nothing; the functional `content-*` utility and the `before`/`after`
      // variants both read it.
      triggers: ["content: var(--tw-content)"],
      members: [
        property_spec(
          "--tw-content",
          "*",
          initial="\"\"",
          initial_before_inherits=true,
        ),
      ],
    },
  ]
}

///|
/// Position of the first declaration that registers `block`, or `None` when the
/// block is never registered.
fn generated_property_block_position(
  css : String,
  block : GeneratedPropertyBlock,
) -> Int? {
  let mut best : Int? = None
  for trigger in block.triggers {
    match index_of(css, trigger) {
      Some(position) =>
        match best {
          Some(current) => if position < current { best = Some(position) }
          None => best = Some(position)
        }
      None => ()
    }
  }
  best
}

///|
/// Whether `--tw-content` is registered by the `before`/`after` variants rather
/// than by a `content-*` utility.
///
/// The two upstream registration sites disagree about declaration order, and
/// the one that appears first in the output wins.
fn content_registered_by_variant(css : String) -> Bool {
  // The functional `content-*` utility declares `--tw-content` and reads it
  // back in the same rule; the variants only read it.
  let mut rest = css
  for ;; {
    guard rest.split_once("--tw-content:") is Some((_, after)) else { break }
    let tail = after.to_owned()
    let boundary = index_of(tail, "}").unwrap_or(tail.length())
    if index_of(tail[:boundary].to_owned(), "content: var(--tw-content)")
      is Some(_) {
      return false
    }
    rest = tail
  }
  true
}

///|
/// Collect the `@layer properties` fallback declarations contributed by author
/// `@property` registrations found in the compiled CSS. Returns the declarations
/// for inheriting properties (emitted on `:root, :host`) and the rest (appended
/// to the universal selector).
fn author_property_defaults(
  css : String,
  span : SourceSpan,
) -> (Array[CssNode], Array[CssNode]) {
  let root : Array[CssNode] = []
  let universal : Array[CssNode] = []
  let nodes = try parse_css(css) catch {
    _ => []
  }
  for node in nodes {
    guard node is AtRule(name="@property", params~, nodes=Some(declarations), ..) else {
      continue
    }
    let name = trim(params)
    let mut inherits_true = false
    let mut initial : String? = None
    for declaration in declarations {
      match declaration {
        Declaration(name="inherits", value~, ..) => inherits_true = trim(value) == "true"
        Declaration(name="initial-value", value~, ..) => initial = Some(value)
        _ => ()
      }
    }
    match initial {
      Some(value) => {
        let entry = Declaration(name~, value~, important=false, span~)
        if inherits_true {
          root.push(entry)
        } else {
          universal.push(entry)
        }
      }
      None => ()
    }
  }
  (root, universal)
}

///|
fn render_generated_properties(
  css : String,
  at_property_fallback? : Bool = true,
) -> (String, String) {
  let blocks : Array[(GeneratedPropertyBlock, Int, Int)] = []
  for index, block in generated_property_blocks() {
    match generated_property_block_position(css, block) {
      Some(position) => blocks.push((block, position, index))
      None => ()
    }
  }
  if blocks.is_empty() {
    return ("", "")
  }
  // Upstream hoists `at-root` nodes in the order the optimized AST reaches
  // them, which is the order the registering declarations are rendered in.
  blocks.sort_by(fn(a, b) {
    let (_, a_position, a_index) = a
    let (_, b_position, b_index) = b
    let by_position = a_position.compare(b_position)
    if by_position != 0 {
      by_position
    } else {
      a_index.compare(b_index)
    }
  })
  let span : SourceSpan = { start: 0, end: 0 }
  let registrations : Array[CssNode] = []
  let defaults : Array[CssNode] = []
  let content_first = content_registered_by_variant(css)
  for entry in blocks {
    let (block, _, _) = entry
    for spec in block.members {
      let initial_before_inherits = if spec.name == "--tw-content" {
        content_first
      } else {
        spec.initial_before_inherits
      }
      let declarations : Array[CssNode] = [
        Declaration(
          name="syntax",
          value="\"\{spec.syntax}\"",
          important=false,
          span~,
        ),
      ]
      if initial_before_inherits {
        match spec.initial {
          Some(initial) =>
            declarations.push(
              Declaration(
                name="initial-value",
                value=initial,
                important=false,
                span~,
              ),
            )
          None => ()
        }
      }
      declarations.push(
        Declaration(name="inherits", value="false", important=false, span~),
      )
      if !initial_before_inherits {
        match spec.initial {
          Some(initial) =>
            declarations.push(
              Declaration(
                name="initial-value",
                value=initial,
                important=false,
                span~,
              ),
            )
          None => ()
        }
      }
      registrations.push(
        AtRule(
          name="@property",
          params=spec.name,
          nodes=Some(declarations),
          span~,
        ),
      )
      defaults.push(
        Declaration(
          name=spec.name,
          value=spec.initial.unwrap_or("initial"),
          important=false,
          span~,
        ),
      )
    }
  }
  if !at_property_fallback {
    return ("", render_css_nodes(registrations))
  }
  // Author `@property` registrations receive the same `@layer properties`
  // fallback as generated ones: inheriting properties on `:root, :host`, the
  // rest appended to the universal selector.
  let (author_root, author_universal) = author_property_defaults(css, span)
  for declaration in author_universal {
    defaults.push(declaration)
  }
  let supports_children : Array[CssNode] = []
  if !author_root.is_empty() {
    supports_children.push(
      Rule(selector=":root, :host", nodes=author_root, span~),
    )
  }
  supports_children.push(
    Rule(selector="*, ::before, ::after, ::backdrop", nodes=defaults, span~),
  )
  registrations.push(
    AtRule(
      name="@layer",
      params="properties",
      nodes=Some([
        AtRule(
          name="@supports",
          params="((-webkit-hyphens: none) and (not (margin-trim: inline))) or ((-moz-orient: inline) and (not (color:rgb(from red r g b))))",
          nodes=Some(supports_children),
          span~,
        ),
      ]),
      span~,
    ),
  )
  (
    render_css_nodes([
      AtRule(name="@layer", params="properties", nodes=None, span~),
    ]),
    render_css_nodes(registrations),
  )
}
