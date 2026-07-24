///|
fn property_order(property : String) -> Int {
  match property {
    "visibility" => 2
    "position" => 3
    "order" => 17
    "margin" => 27
    "margin-inline" => 28
    "margin-block" => 29
    "margin-top" => 34
    "margin-right" => 35
    "margin-bottom" => 36
    "margin-left" => 37
    "display" => 39
    "height" => 42
    "max-height" => 43
    "min-height" => 44
    "width" => 45
    "max-width" => 46
    "min-width" => 47
    "flex" => 48
    "flex-shrink" => 49
    "flex-grow" => 50
    "flex-basis" => 51
    "border-spacing" => 55
    "transform-origin" => 56
    "translate" => 57
    "--tw-translate-x" => 58
    "--tw-translate-y" => 59
    "--tw-translate-z" => 60
    "scale" => 61
    "--tw-scale-x" => 62
    "--tw-scale-y" => 63
    "--tw-scale-z" => 64
    "rotate" => 65
    "--tw-rotate-x" => 66
    "--tw-rotate-y" => 67
    "--tw-rotate-z" => 68
    "--tw-skew-x" => 69
    "--tw-skew-y" => 70
    "transform" => 71
    "animation" => 73
    "touch-action" => 75
    "--tw-pan-x" => 76
    "--tw-pan-y" => 77
    "--tw-pinch-zoom" => 78
    "scroll-snap-type" => 80
    "--tw-scroll-snap-strictness" => 81
    "scroll-margin" => 84
    "scroll-margin-inline-start" => 87
    "scroll-padding-inline" => 96
    "scroll-padding-block-end" => 101
    "list-style-position" => 109
    "list-style-type" => 110
    "list-style-image" => 111
    "columns" => 113
    "gap" => 130
    "column-gap" => 131
    "row-gap" => 132
    "--tw-space-x-reverse" => 133
    "--tw-space-y-reverse" => 134
    "divide-x-width" => 135
    "divide-y-width" => 136
    "--tw-divide-y-reverse" => 137
    "divide-style" => 138
    "divide-color" => 139
    "overflow" => 143
    "border-radius" => 150
    "border-start-radius" => 151
    "border-end-radius" => 152
    "border-top-radius" => 153
    "border-right-radius" => 154
    "border-bottom-radius" => 155
    "border-left-radius" => 156
    "border-start-start-radius" => 157
    "border-start-end-radius" => 158
    "border-end-end-radius" => 159
    "border-end-start-radius" => 160
    "border-top-left-radius" => 161
    "border-top-right-radius" => 162
    "border-bottom-right-radius" => 163
    "border-bottom-left-radius" => 164
    "border-width" => 165
    "border-inline-width" => 166
    "border-block-width" => 167
    "border-inline-start-width" => 168
    "border-inline-end-width" => 169
    "border-block-start-width" => 170
    "border-block-end-width" => 171
    "border-top-width" => 172
    "border-right-width" => 173
    "border-bottom-width" => 174
    "border-left-width" => 175
    "border-style" => 176
    "border-inline-style" => 177
    "border-block-style" => 178
    "border-inline-start-style" => 179
    "border-inline-end-style" => 180
    "border-block-start-style" => 181
    "border-block-end-style" => 182
    "border-top-style" => 183
    "border-right-style" => 184
    "border-bottom-style" => 185
    "border-left-style" => 186
    "border-color" => 187
    "border-inline-color" => 188
    "border-block-color" => 189
    "border-inline-start-color" => 190
    "border-inline-end-color" => 191
    "border-block-start-color" => 192
    "border-block-end-color" => 193
    "border-top-color" => 194
    "border-right-color" => 195
    "border-bottom-color" => 196
    "border-left-color" => 197
    "background-color" => 198
    "background-image" => 199
    "--tw-gradient-position" => 200
    "--tw-gradient-stops" => 201
    "--tw-gradient-via-stops" => 202
    "--tw-gradient-from" => 203
    "--tw-gradient-from-position" => 204
    "--tw-gradient-via" => 205
    "--tw-gradient-via-position" => 206
    "--tw-gradient-to" => 207
    "--tw-gradient-to-position" => 208
    "background-size" => 251
    "background-attachment" => 252
    "background-clip" => 253
    "background-position" => 254
    "background-repeat" => 255
    "background-origin" => 256
    "fill" => 265
    "stroke" => 266
    "stroke-width" => 267
    "padding" => 270
    "padding-inline" => 271
    "padding-block" => 272
    "padding-top" => 277
    "padding-right" => 278
    "padding-bottom" => 279
    "padding-left" => 280
    "text-indent" => 282
    "vertical-align" => 283
    "font-family" => 284
    "font-feature-settings" => 285
    "font-size" => 286
    "line-height" => 287
    "font-weight" => 288
    "letter-spacing" => 289
    "tab-size" => 296
    "color" => 297
    "font-variant-numeric" => 301
    "text-decoration-color" => 303
    "text-decoration-style" => 304
    "text-decoration-thickness" => 305
    "text-underline-offset" => 306
    "placeholder-color" => 308
    "color-scheme" => 311
    "opacity" => 312
    "background-blend-mode" => 313
    "mix-blend-mode" => 314
    "box-shadow" => 315
    "--tw-shadow" => 316
    "--tw-shadow-color" => 317
    "--tw-ring-shadow" => 318
    "--tw-ring-color" => 319
    "--tw-inset-shadow" => 320
    "--tw-inset-shadow-color" => 321
    "--tw-inset-ring-shadow" => 322
    "--tw-inset-ring-color" => 323
    "--tw-ring-offset-width" => 324
    "--tw-ring-offset-color" => 325
    "outline" => 326
    "outline-width" => 327
    "outline-offset" => 328
    "outline-color" => 329
    "--tw-blur" => 330
    "--tw-brightness" => 331
    "--tw-contrast" => 332
    "--tw-drop-shadow" => 333
    "--tw-grayscale" => 334
    "--tw-hue-rotate" => 335
    "--tw-invert" => 336
    "--tw-saturate" => 337
    "--tw-sepia" => 338
    "filter" => 339
    "--tw-backdrop-blur" => 340
    "--tw-backdrop-brightness" => 341
    "--tw-backdrop-contrast" => 342
    "--tw-backdrop-grayscale" => 343
    "--tw-backdrop-hue-rotate" => 344
    "--tw-backdrop-invert" => 345
    "--tw-backdrop-opacity" => 346
    "--tw-backdrop-saturate" => 347
    "--tw-backdrop-sepia" => 348
    "backdrop-filter" | "-webkit-backdrop-filter" => 349
    "transition-property" => 350
    "transition-delay" => 352
    "transition-duration" => 353
    "transition-timing-function" => 354
    "content" => 357
    "forced-color-adjust" => 358
    _ => 500
  }
}

///|
priv struct RenderedCandidate {
  candidate : String
  property_orders : Array[Int]
  declaration_count : Int
  variant_orders : Array[VariantKey]
  nodes : Array[CssNode]
}

///|
/// Order two compiled candidates the way upstream sorts generated rules.
fn compare_rendered_candidates(
  a : RenderedCandidate,
  b : RenderedCandidate,
) -> Int {
  let by_variant = compare_variant_orders(a.variant_orders, b.variant_orders)
  if by_variant != 0 {
    return by_variant
  }
  let by_property = compare_property_orders(
    a.property_orders,
    b.property_orders,
  )
  if by_property != 0 {
    return by_property
  }
  let by_count = b.declaration_count.compare(a.declaration_count)
  if by_count != 0 {
    return by_count
  }
  candidate_lexical_compare(a.candidate, b.candidate)
}

///|
fn declarations_to_css_nodes(
  declarations : ArrayView[Declaration],
  important~ : Bool,
) -> Array[CssNode] {
  let nodes : Array[CssNode] = []
  let span : SourceSpan = { start: 0, end: 0 }
  for declaration in declarations {
    match declaration.fallback {
      Some(fallback) => {
        nodes.push(
          Declaration(
            name=declaration.property,
            value=fallback,
            important~,
            span~,
          ),
        )
        nodes.push(
          AtRule(
            name="@supports",
            params="(color: color-mix(in lab, red, red))",
            nodes=Some([
              Declaration(
                name=declaration.property,
                value=declaration.value,
                important~,
                span~,
              ),
            ]),
            span~,
          ),
        )
      }
      None =>
        nodes.push(
          Declaration(
            name=declaration.property,
            value=declaration.value,
            important~,
            span~,
          ),
        )
    }
  }
  nodes
}

///|
fn replace_candidate_selector_nodes(
  nodes : ArrayView[CssNode],
  current_selector : String,
  next_selector : String,
) -> Array[CssNode] {
  nodes.map(fn(node) {
    match node {
      Rule(selector~, nodes~, span~) =>
        Rule(
          selector=replace_all(selector, current_selector, next_selector),
          nodes=replace_candidate_selector_nodes(
            nodes, current_selector, next_selector,
          ),
          span~,
        )
      AtRule(name~, params~, nodes=Some(children), span~) =>
        AtRule(
          name~,
          params~,
          nodes=Some(
            replace_candidate_selector_nodes(
              children, current_selector, next_selector,
            ),
          ),
          span~,
        )
      Context(values~, nodes~, span~) =>
        Context(
          values~,
          nodes=replace_candidate_selector_nodes(
            nodes, current_selector, next_selector,
          ),
          span~,
        )
      AtRoot(nodes~, span~) =>
        AtRoot(
          nodes=replace_candidate_selector_nodes(
            nodes, current_selector, next_selector,
          ),
          span~,
        )
      _ => node
    }
  })
}

///|
fn wrap_candidate_at_rule(
  nodes : Array[CssNode],
  name : String,
  params : String,
) -> Array[CssNode] {
  let output : Array[CssNode] = []
  let pending : Array[CssNode] = []
  let flush = fn() {
    if !pending.is_empty() {
      output.push(
        AtRule(name~, params~, nodes=Some(pending.copy()), span={
          start: 0,
          end: 0,
        }),
      )
      pending.clear()
    }
  }
  for node in nodes {
    match node {
      AtRoot(..) => {
        flush()
        output.push(node)
      }
      AtRule(
        name=existing_name,
        params=existing_params,
        nodes=Some(children),
        span~
      ) => {
        flush()
        output.push(
          AtRule(
            name=existing_name,
            params=existing_params,
            nodes=Some(wrap_candidate_at_rule(children, name, params)),
            span~,
          ),
        )
      }
      _ => pending.push(node)
    }
  }
  flush()
  output
}

///|
fn candidate_rule_children(
  nodes : ArrayView[CssNode],
  selector : String,
) -> Array[CssNode]? {
  match nodes {
    [Rule(selector=rule_selector, nodes=children, ..)] if rule_selector ==
      selector => Some(children.copy())
    _ => None
  }
}

///|
fn substitute_custom_variant_nodes(
  template : ArrayView[CssNode],
  slot_nodes : Array[CssNode],
  selector : String,
  inside_rule : Bool,
  theme : Map[String, String],
  custom_variants : Map[String, CustomVariantTemplate],
  variant_stack : Array[String],
) -> Array[CssNode]? {
  let output : Array[CssNode] = []
  for node in template {
    match node {
      AtRule(name="@slot", nodes=None, ..) =>
        if inside_rule {
          match candidate_rule_children(slot_nodes, selector) {
            Some(children) => output.append(children)
            None => output.append(slot_nodes)
          }
        } else {
          output.append(slot_nodes)
        }
      AtRule(name="@variant", params~, nodes=Some(children), ..) => {
        guard apply_variant_to_nodes(
            trim(params),
            slot_nodes,
            selector,
            theme,
            custom_variants,
            variant_stack,
          )
          is Some((variant_nodes, variant_selector)) else {
          return None
        }
        guard substitute_custom_variant_nodes(
            children, variant_nodes, variant_selector, inside_rule, theme, custom_variants,
            variant_stack,
          )
          is Some(substituted) else {
          return None
        }
        output.append(substituted)
      }
      Rule(selector=template_selector, nodes=children, span~) => {
        let next_selector = rewrite_arbitrary_selector(
          template_selector, selector,
        )
        let retains_rule = children.any(fn(child) {
          child is Declaration(..) ||
          child is AtRule(name="@slot", nodes=None, ..)
        })
        let selected = replace_candidate_selector_nodes(
          slot_nodes, selector, next_selector,
        )
        guard substitute_custom_variant_nodes(
            children, selected, next_selector, retains_rule, theme, custom_variants,
            variant_stack,
          )
          is Some(substituted) else {
          return None
        }
        if !retains_rule &&
          substituted.all(fn(child) {
            child is Rule(..) || child is AtRule(nodes=Some(_), ..)
          }) {
          output.append(substituted)
        } else {
          output.push(
            Rule(
              selector=if inside_rule {
                template_selector
              } else {
                next_selector
              },
              nodes=substituted,
              span~,
            ),
          )
        }
      }
      AtRule(name~, params~, nodes=Some(children), span~) => {
        guard substitute_custom_variant_nodes(
            children, slot_nodes, selector, false, theme, custom_variants, variant_stack,
          )
          is Some(substituted) else {
          return None
        }
        output.push(AtRule(name~, params~, nodes=Some(substituted), span~))
      }
      Context(values~, nodes=children, span~) => {
        guard substitute_custom_variant_nodes(
            children, slot_nodes, selector, inside_rule, theme, custom_variants,
            variant_stack,
          )
          is Some(substituted) else {
          return None
        }
        output.push(Context(values~, nodes=substituted, span~))
      }
      AtRoot(nodes=children, span~) => {
        guard substitute_custom_variant_nodes(
            children, slot_nodes, selector, false, theme, custom_variants, variant_stack,
          )
          is Some(substituted) else {
          return None
        }
        output.push(AtRoot(nodes=substituted, span~))
      }
      _ => output.push(node)
    }
  }
  Some(output)
}

///|
fn simple_variant_selector(variant : String, selector : String) -> String? {
  match variant {
    "*" => Some(":is(\{selector} > *)")
    "**" => Some(":is(\{selector} *)")
    "first-letter" => Some("\{selector}::first-letter")
    "first-line" => Some("\{selector}::first-line")
    "file" => Some("\{selector}::file-selector-button")
    "placeholder" => Some("\{selector}::placeholder")
    "backdrop" => Some("\{selector}::backdrop")
    "details-content" => Some("\{selector}::details-content")
    "focus" => Some("\{selector}:focus")
    "focus-within" => Some("\{selector}:focus-within")
    "focus-visible" => Some("\{selector}:focus-visible")
    "active" => Some("\{selector}:active")
    "visited" => Some("\{selector}:visited")
    "target" => Some("\{selector}:target")
    "open" => Some("\{selector}:is([open], :popover-open, :open)")
    "default" => Some("\{selector}:default")
    "checked" => Some("\{selector}:checked")
    "indeterminate" => Some("\{selector}:indeterminate")
    "placeholder-shown" => Some("\{selector}:placeholder-shown")
    "autofill" => Some("\{selector}:autofill")
    "optional" => Some("\{selector}:optional")
    "required" => Some("\{selector}:required")
    "valid" => Some("\{selector}:valid")
    "invalid" => Some("\{selector}:invalid")
    "user-valid" => Some("\{selector}:user-valid")
    "user-invalid" => Some("\{selector}:user-invalid")
    "in-range" => Some("\{selector}:in-range")
    "out-of-range" => Some("\{selector}:out-of-range")
    "read-only" => Some("\{selector}:read-only")
    "empty" => Some("\{selector}:empty")
    "enabled" => Some("\{selector}:enabled")
    "disabled" => Some("\{selector}:disabled")
    "first" => Some("\{selector}:first-child")
    "last" => Some("\{selector}:last-child")
    "only" => Some("\{selector}:only-child")
    "odd" => Some("\{selector}:nth-child(odd)")
    "even" => Some("\{selector}:nth-child(even)")
    "first-of-type" => Some("\{selector}:first-of-type")
    "last-of-type" => Some("\{selector}:last-of-type")
    "only-of-type" => Some("\{selector}:only-of-type")
    "inert" => Some("\{selector}:is([inert], [inert] *)")
    "ltr" =>
      Some("\{selector}:where(:dir(ltr), [dir=\"ltr\"], [dir=\"ltr\"] *)")
    "rtl" =>
      Some("\{selector}:where(:dir(rtl), [dir=\"rtl\"], [dir=\"rtl\"] *)")
    _ => None
  }
}

///|
fn expand_pseudo_element_rules(
  nodes : ArrayView[CssNode],
  selector : String,
  selectors : ArrayView[String],
) -> Array[CssNode] {
  let output : Array[CssNode] = []
  for node in nodes {
    match node {
      Rule(selector=rule_selector, nodes=children, span~) =>
        if rule_selector.contains(selector) {
          for next_selector in selectors {
            output.push(
              Rule(
                selector=replace_all(rule_selector, selector, next_selector),
                nodes=children.copy(),
                span~,
              ),
            )
          }
        } else {
          output.push(node)
        }
      AtRule(name~, params~, nodes=Some(children), span~) =>
        output.push(
          AtRule(
            name~,
            params~,
            nodes=Some(
              expand_pseudo_element_rules(children, selector, selectors),
            ),
            span~,
          ),
        )
      Context(values~, nodes=children, span~) =>
        output.push(
          Context(
            values~,
            nodes=expand_pseudo_element_rules(children, selector, selectors),
            span~,
          ),
        )
      AtRoot(nodes=children, span~) =>
        output.push(
          AtRoot(
            nodes=expand_pseudo_element_rules(children, selector, selectors),
            span~,
          ),
        )
      _ => output.push(node)
    }
  }
  output
}

///|
fn add_content_declaration(
  nodes : ArrayView[CssNode],
  selector : String,
) -> Array[CssNode] {
  nodes.map(fn(node) {
    match node {
      Rule(selector=rule_selector, nodes=children, span~) =>
        if rule_selector.contains(selector) {
          let next_children : Array[CssNode] = [
            Declaration(
              name="content",
              value="var(--tw-content)",
              important=false,
              span={ start: 0, end: 0 },
            ),
          ]
          next_children.append(children)
          Rule(selector=rule_selector, nodes=next_children, span~)
        } else {
          node
        }
      AtRule(name~, params~, nodes=Some(children), span~) =>
        AtRule(
          name~,
          params~,
          nodes=Some(add_content_declaration(children, selector)),
          span~,
        )
      Context(values~, nodes=children, span~) =>
        Context(
          values~,
          nodes=add_content_declaration(children, selector),
          span~,
        )
      _ => node
    }
  })
}

///|
fn simple_media_condition(variant : String) -> String? {
  match variant {
    "hover" => Some("(hover: hover)")
    "dark" => Some("(prefers-color-scheme: dark)")
    "motion-safe" => Some("(prefers-reduced-motion: no-preference)")
    "motion-reduce" => Some("(prefers-reduced-motion: reduce)")
    "contrast-more" => Some("(prefers-contrast: more)")
    "contrast-less" => Some("(prefers-contrast: less)")
    "portrait" => Some("(orientation: portrait)")
    "landscape" => Some("(orientation: landscape)")
    "print" => Some("print")
    "forced-colors" => Some("(forced-colors: active)")
    "inverted-colors" => Some("(inverted-colors: inverted)")
    "pointer-none" => Some("(pointer: none)")
    "pointer-coarse" => Some("(pointer: coarse)")
    "pointer-fine" => Some("(pointer: fine)")
    "any-pointer-none" => Some("(any-pointer: none)")
    "any-pointer-coarse" => Some("(any-pointer: coarse)")
    "any-pointer-fine" => Some("(any-pointer: fine)")
    "noscript" => Some("(scripting: none)")
    _ => None
  }
}

///|
fn apply_variant_to_nodes(
  variant : String,
  nodes : Array[CssNode],
  selector : String,
  theme : Map[String, String],
  custom_variants : Map[String, CustomVariantTemplate],
  variant_stack : Array[String],
) -> (Array[CssNode], String)? {
  if variant_stack.contains(variant) {
    return None
  }
  match custom_variants.get(variant) {
    Some(CustomVariantSelector(template)) => {
      let next_selector = rewrite_arbitrary_selector(template, selector)
      return Some(
        (
          replace_candidate_selector_nodes(nodes, selector, next_selector),
          next_selector,
        ),
      )
    }
    Some(CustomVariantNodes(template)) => {
      let next_stack = variant_stack.copy()
      next_stack.push(variant)
      guard substitute_custom_variant_nodes(
          template, nodes, selector, false, theme, custom_variants, next_stack,
        )
        is Some(substituted) else {
        return None
      }
      return Some((substituted, selector))
    }
    None => ()
  }
  if variant == "marker" {
    let selectors = [
      "\{selector} ::marker",
      "\{selector}::marker",
      "\{selector} ::-webkit-details-marker",
      "\{selector}::-webkit-details-marker",
    ]
    return Some(
      (expand_pseudo_element_rules(nodes, selector, selectors), selector),
    )
  }
  if variant == "selection" {
    let selectors = ["\{selector} ::selection", "\{selector}::selection"]
    return Some(
      (expand_pseudo_element_rules(nodes, selector, selectors), selector),
    )
  }
  if variant == "before" || variant == "after" {
    let next_selector = "\{selector}::\{variant}"
    let selected = replace_candidate_selector_nodes(
      nodes, selector, next_selector,
    )
    let with_content = add_content_declaration(selected, next_selector)
    return Some((with_content, next_selector))
  }
  if simple_variant_selector(variant, selector) is Some(next_selector) {
    return Some(
      (
        replace_candidate_selector_nodes(nodes, selector, next_selector),
        next_selector,
      ),
    )
  }
  let (context_kind, context_inner) = if variant.has_prefix("not-") {
    (Some("not"), variant[4:].to_owned())
  } else if variant.has_prefix("in-") {
    (Some("in"), variant[3:].to_owned())
  } else {
    (None, "")
  }
  if context_kind is Some(kind) && context_inner != "" {
    if is_never_compound_variant(context_inner) {
      return None
    }
    if kind == "in" {
      match arbitrary_ancestor_selector(context_inner) {
        Some(ancestor) => {
          let next_selector = ":where(\{ancestor}) \{selector}"
          return Some(
            (
              replace_candidate_selector_nodes(nodes, selector, next_selector),
              next_selector,
            ),
          )
        }
        None => ()
      }
    }
    let synthetic_span : SourceSpan = { start: 0, end: 0 }
    let synthetic : Array[CssNode] = [
      Rule(selector="&", nodes=[], span=synthetic_span),
    ]
    let next_stack = variant_stack.copy()
    next_stack.push(variant)
    guard apply_variant_to_nodes(
        context_inner, synthetic, "&", theme, custom_variants, next_stack,
      )
      is Some((inner_nodes, _)) else {
      return None
    }
    match inner_nodes {
      [Rule(selector=inner_selector, ..)] => {
        if inner_selector.contains("::") {
          return None
        }
        let condition = remove_leading_universal_list(
          rewrite_selector_nesting_only(inner_selector, "*"),
        )
        let next_selector = if kind == "not" {
          "\{selector}:not(\{condition})"
        } else {
          ":where(\{condition}) \{selector}"
        }
        return Some(
          (
            replace_candidate_selector_nodes(nodes, selector, next_selector),
            next_selector,
          ),
        )
      }
      [
        AtRule(
          name~,
          params~,
          nodes=Some([Rule(selector=inner_selector, ..)]),
          ..
        ),
      ] if kind == "not" => {
        if name != "@media" && name != "@supports" && name != "@container" {
          return None
        }
        if has_top_level_comma(params) {
          return None
        }
        let negated = wrap_candidate_at_rule(
          nodes.copy(),
          name,
          negate_condition(name, params),
        )
        if inner_selector == "&" {
          return Some((negated, selector))
        }
        let condition = remove_leading_universal_list(
          rewrite_selector_nesting_only(inner_selector, "*"),
        )
        let next_selector = "\{selector}:not(\{condition})"
        let positive = replace_candidate_selector_nodes(
          nodes, selector, next_selector,
        )
        positive.append(negated)
        return Some((positive, next_selector))
      }
      _ => return None
    }
  }
  if variant.has_prefix("supports-") {
    let (variant, modifier) = split_modifier(variant)
    if modifier is Some(_) {
      return None
    }
    let raw = variant["supports-".length():].to_owned()
    if raw == "" {
      return None
    }
    let mut condition = if raw.has_prefix("[") && raw.has_suffix("]") {
      decode_arbitrary(raw[1:raw.length() - 1].to_owned())
    } else {
      raw
    }
    if condition == "" {
      return None
    }
    let function_like = condition.contains("(") && condition.has_suffix(")")
    if !function_like {
      if !condition.contains(":") {
        condition = "\{condition}: var(--tw)"
      }
      if !condition.has_prefix("(") || !condition.has_suffix(")") {
        condition = "(\{condition})"
      }
    }
    return Some(
      (wrap_candidate_at_rule(nodes, "@supports", condition), selector),
    )
  }
  if variant.has_prefix("min-") || variant.has_prefix("max-") {
    let (variant, modifier) = split_modifier(variant)
    if modifier is Some(_) {
      return None
    }
    let (minimum, key) = if variant.has_prefix("min-") {
      (true, variant[4:].to_owned())
    } else {
      (false, variant[4:].to_owned())
    }
    let width = if key.has_prefix("[") && key.has_suffix("]") {
      decode_arbitrary(key[1:key.length() - 1].to_owned())
    } else {
      match theme.get("--breakpoint-\{key}") {
        Some(width) => width
        None => return None
      }
    }
    if width == "" || width.contains("var(") {
      return None
    }
    let condition = if minimum {
      "(width >= \{width})"
    } else {
      "(width < \{width})"
    }
    return Some((wrap_candidate_at_rule(nodes, "@media", condition), selector))
  }
  if variant.has_prefix("@") {
    let (query, container_name) = split_modifier(variant[1:].to_owned())
    let (minimum, key) = if query.has_prefix("min-") {
      (true, query[4:].to_owned())
    } else if query.has_prefix("max-") {
      (false, query[4:].to_owned())
    } else {
      (true, query)
    }
    let width = if key.has_prefix("[") && key.has_suffix("]") {
      decode_arbitrary(key[1:key.length() - 1].to_owned())
    } else {
      match theme.get("--container-\{key}") {
        Some(width) => width
        None => return None
      }
    }
    let condition = if minimum {
      "(width >= \{width})"
    } else {
      "(width < \{width})"
    }
    let params = match container_name {
      Some(name) => "\{name} \{condition}"
      None => condition
    }
    return Some((wrap_candidate_at_rule(nodes, "@container", params), selector))
  }
  if simple_variant_selector(variant, selector) is Some(next_selector) {
    return Some(
      (
        replace_candidate_selector_nodes(nodes, selector, next_selector),
        next_selector,
      ),
    )
  }
  if simple_media_condition(variant) is Some(condition) {
    let next_selector = if variant == "hover" {
      "\{selector}:hover"
    } else {
      selector
    }
    let selected = if next_selector == selector {
      nodes
    } else {
      replace_candidate_selector_nodes(nodes, selector, next_selector)
    }
    return Some(
      (wrap_candidate_at_rule(selected, "@media", condition), next_selector),
    )
  }
  match
    apply_group_peer_variant(
      variant, nodes, selector, theme, custom_variants, variant_stack,
    ) {
    Some(result) => return Some(result)
    None => ()
  }
  match
    apply_has_variant(
      variant, nodes, selector, theme, custom_variants, variant_stack,
    ) {
    Some(result) => return Some(result)
    None => ()
  }
  match compound_state_variant(variant, selector) {
    Some((next_selector, hover)) => {
      let selected = replace_candidate_selector_nodes(
        nodes, selector, next_selector,
      )
      return Some(
        (
          if hover {
            wrap_candidate_at_rule(selected, "@media", "(hover: hover)")
          } else {
            selected
          },
          next_selector,
        ),
      )
    }
    None => ()
  }
  let selector_result = match direct_has_variant(variant, selector) {
    Some(result) => Some(result)
    None =>
      match nth_variant(variant, selector) {
        Some(result) => Some(result)
        None => attribute_variant(variant, selector)
      }
  }
  match selector_result {
    Some(next_selector) =>
      return Some(
        (
          replace_candidate_selector_nodes(nodes, selector, next_selector),
          next_selector,
        ),
      )
    None => ()
  }
  if variant.has_prefix("[") && variant.has_suffix("]") {
    let arbitrary = decode_arbitrary(variant[1:variant.length() - 1].to_owned())
    if arbitrary.has_prefix("@") {
      let (name, params) = match arbitrary.split_once(" ") {
        Some((name, params)) => (name.to_owned(), params.to_owned())
        None => (arbitrary, "")
      }
      return Some((wrap_candidate_at_rule(nodes, name, params), selector))
    }
    let ast = parse_selector(arbitrary)
    let next_selector = if selector_contains_nesting(ast) {
      render_selector(replace_selector_nesting(ast, selector))
    } else {
      // A bare arbitrary variant qualifies the element itself, so upstream
      // wraps it as `&:is(…)`.
      "\{selector}:is(\{render_selector(ast)})"
    }
    return Some(
      (
        replace_candidate_selector_nodes(nodes, selector, next_selector),
        next_selector,
      ),
    )
  }
  match theme.get("--breakpoint-\{variant}") {
    Some(width) =>
      Some(
        (
          wrap_candidate_at_rule(nodes, "@media", "(width >= \{width})"),
          selector,
        ),
      )
    None =>
      if variant == "starting" {
        Some((wrap_candidate_at_rule(nodes, "@starting-style", ""), selector))
      } else {
        None
      }
  }
}

///|
fn apply_has_variant(
  variant : String,
  nodes : Array[CssNode],
  selector : String,
  theme : Map[String, String],
  custom_variants : Map[String, CustomVariantTemplate],
  variant_stack : Array[String],
) -> (Array[CssNode], String)? {
  if !variant.has_prefix("has-") {
    return None
  }
  let (inner, modifier) = split_modifier(variant[4:].to_owned())
  if inner == "" || modifier is Some(_) || is_never_compound_variant(inner) {
    return None
  }
  if inner.has_prefix("[") && inner.has_suffix("]") {
    guard has_selector(inner) is Some(condition) else { return None }
    let next_selector = "\{selector}:has(\{condition})"
    return Some(
      (
        replace_candidate_selector_nodes(nodes, selector, next_selector),
        next_selector,
      ),
    )
  }
  let synthetic_span : SourceSpan = { start: 0, end: 0 }
  let next_stack = variant_stack.copy()
  next_stack.push(variant)
  guard apply_variant_to_nodes(
      inner,
      [Rule(selector="&", nodes=[], span=synthetic_span)],
      "&",
      theme,
      custom_variants,
      next_stack,
    )
    is Some((inner_nodes, _)) else {
    return None
  }
  guard inner_nodes is [Rule(selector=inner_selector, ..)] else { return None }
  if inner_selector.contains("::") {
    return None
  }
  let condition = remove_leading_universal_list(
    replace_all(inner_selector, "&", "*"),
  )
  let next_selector = "\{selector}:has(\{condition})"
  Some(
    (
      replace_candidate_selector_nodes(nodes, selector, next_selector),
      next_selector,
    ),
  )
}

///|
fn apply_group_peer_variant(
  variant : String,
  nodes : Array[CssNode],
  selector : String,
  theme : Map[String, String],
  custom_variants : Map[String, CustomVariantTemplate],
  variant_stack : Array[String],
) -> (Array[CssNode], String)? {
  let (kind, raw_inner) = if variant.has_prefix("group-") {
    ("group", variant[6:].to_owned())
  } else if variant.has_prefix("peer-") {
    ("peer", variant[5:].to_owned())
  } else {
    return None
  }
  let (inner, marker_name) = split_modifier(raw_inner)
  if inner == "" {
    return None
  }
  if is_never_compound_variant(inner) {
    return None
  }
  let synthetic_span : SourceSpan = { start: 0, end: 0 }
  let next_stack = variant_stack.copy()
  next_stack.push(variant)
  guard apply_variant_to_nodes(
      inner,
      [Rule(selector="&", nodes=[], span=synthetic_span)],
      "&",
      theme,
      custom_variants,
      next_stack,
    )
    is Some((inner_nodes, _)) else {
    return None
  }
  guard inner_nodes is [Rule(selector=inner_selector, ..)] else { return None }
  if inner_selector.contains("::") {
    return None
  }
  let marker = match marker_name {
    Some(name) => escape_class_name("\{kind}/\{name}")
    None => kind
  }
  let marker_selector = ":where(.\{marker})"
  let mut condition = replace_all(inner_selector, "&", marker_selector)
  if has_top_level_comma(condition) {
    condition = ":is(\{condition})"
  }
  let relation = if kind == "group" { " *" } else { " ~ *" }
  let next_selector = "\{selector}:is(\{condition}\{relation})"
  Some(
    (
      replace_candidate_selector_nodes(nodes, selector, next_selector),
      next_selector,
    ),
  )
}

///|
fn is_never_compound_variant(variant : String) -> Bool {
  let non_compoundable = [
    "*", "**", "first-letter", "first-line", "marker", "selection", "file", "placeholder",
    "backdrop", "details-content", "before", "after",
  ]
  if non_compoundable.contains(variant) {
    return true
  }
  if variant.has_prefix("[") && variant.has_suffix("]") {
    let selector = trim(
      decode_arbitrary(variant[1:variant.length() - 1].to_owned()),
    )
    return selector.has_prefix(">") ||
      selector.has_prefix("+") ||
      selector.has_prefix("~")
  }
  false
}

///|
fn has_top_level_comma(input : String) -> Bool {
  let mut round = 0
  let mut square = 0
  for character in input {
    match character {
      '(' => round += 1
      ')' => round -= 1
      '[' => square += 1
      ']' => square -= 1
      ',' if round == 0 && square == 0 => return true
      _ => ()
    }
  }
  false
}

///|
/// A comparable sort key for one variant, mirroring the upstream variant graph.
///
/// `base` is the registration order of the variant's root. Variants that share
/// a root are ordered by the remaining fields: grouped media families by their
/// width, functional families by their value, compound variants by their inner
/// variant and modifier, and arbitrary variants by their selector.
priv struct VariantKey {
  base : Int
  width : (String, Double)?
  descending : Bool
  value : String?
  value_arbitrary : Bool
  arbitrary : String?
  inner : VariantKey?
  modifier : String?
} derive(Eq)

///|
fn VariantKey::simple(base : Int) -> VariantKey {
  {
    base,
    width: None,
    descending: false,
    value: None,
    value_arbitrary: false,
    arbitrary: None,
    inner: None,
    modifier: None,
  }
}

///|
/// Registration order of a static variant, or `None` when it is not one.
fn static_variant_base(name : String) -> Int? {
  match name {
    "*" => Some(1)
    "**" => Some(2)
    "first-letter" => Some(6)
    "first-line" => Some(7)
    "marker" => Some(8)
    "selection" => Some(9)
    "file" => Some(10)
    "placeholder" => Some(11)
    "backdrop" => Some(12)
    "details-content" => Some(13)
    "before" => Some(14)
    "after" => Some(15)
    "first" => Some(16)
    "last" => Some(17)
    "only" => Some(18)
    "odd" => Some(19)
    "even" => Some(20)
    "first-of-type" => Some(21)
    "last-of-type" => Some(22)
    "only-of-type" => Some(23)
    "visited" => Some(24)
    "target" => Some(25)
    "open" => Some(26)
    "default" => Some(27)
    "checked" => Some(28)
    "indeterminate" => Some(29)
    "placeholder-shown" => Some(30)
    "autofill" => Some(31)
    "optional" => Some(32)
    "required" => Some(33)
    "valid" => Some(34)
    "invalid" => Some(35)
    "user-valid" => Some(36)
    "user-invalid" => Some(37)
    "in-range" => Some(38)
    "out-of-range" => Some(39)
    "read-only" => Some(40)
    "empty" => Some(41)
    "focus-within" => Some(42)
    "hover" => Some(43)
    "focus" => Some(44)
    "focus-visible" => Some(45)
    "active" => Some(46)
    "enabled" => Some(47)
    "disabled" => Some(48)
    "inert" => Some(49)
    "motion-safe" => Some(59)
    "motion-reduce" => Some(60)
    "contrast-more" => Some(61)
    "contrast-less" => Some(62)
    "portrait" => Some(67)
    "landscape" => Some(68)
    "ltr" => Some(69)
    "rtl" => Some(70)
    "dark" => Some(71)
    "starting" => Some(72)
    "print" => Some(73)
    "forced-colors" => Some(74)
    "inverted-colors" => Some(75)
    "pointer-none" => Some(76)
    "pointer-coarse" => Some(77)
    "pointer-fine" => Some(78)
    "any-pointer-none" => Some(79)
    "any-pointer-coarse" => Some(80)
    "any-pointer-fine" => Some(81)
    "noscript" => Some(82)
    _ => None
  }
}

///|
/// Parse a width token into its unit and numeric value.
fn variant_width_parts(width : String) -> (String, Double)? {
  match split_numeric(trim(width)) {
    Some((value, unit)) => Some((unit, value))
    None => None
  }
}

///|
/// Resolve a breakpoint or container width, whether named or arbitrary.
fn variant_width(
  key : String,
  theme_namespace : String,
  theme : Map[String, String],
) -> (String, Double)? {
  let raw = if key.has_prefix("[") && key.has_suffix("]") {
    decode_arbitrary(key[1:key.length() - 1].to_owned())
  } else {
    match theme.get("\{theme_namespace}-\{key}") {
      Some(width) => width
      None => return None
    }
  }
  variant_width_parts(raw)
}

///|
/// Build the sort key for one variant.
fn variant_key(
  variant : String,
  theme : Map[String, String],
  custom_variants : Map[String, CustomVariantTemplate],
) -> VariantKey {
  // Arbitrary variants sort after every named variant, by their selector.
  // A bare selector is compared in its `&:is(…)` form, matching how upstream
  // stores it.
  if variant.has_prefix("[") && variant.has_suffix("]") {
    let decoded = decode_arbitrary(variant[1:variant.length() - 1].to_owned())
    let key = if decoded.contains("&") { decoded } else { "&:is(\{decoded})" }
    return { ..VariantKey::simple(10000), arbitrary: Some(key) }
  }
  // Compound variants take their root's order and defer to the inner variant.
  let compound = if variant.has_prefix("not-") {
    Some((3, variant[4:].to_owned()))
  } else if variant.has_prefix("group-") {
    Some((4, variant[6:].to_owned()))
  } else if variant.has_prefix("peer-") {
    Some((5, variant[5:].to_owned()))
  } else if variant.has_prefix("in-") {
    Some((50, variant[3:].to_owned()))
  } else if variant.has_prefix("has-") {
    Some((51, variant[4:].to_owned()))
  } else {
    None
  }
  match compound {
    Some((base, rest)) => {
      let (inner, modifier) = split_modifier(rest)
      return {
        ..VariantKey::simple(base),
        inner: Some(variant_key(inner, theme, custom_variants)),
        modifier,
      }
    }
    None => ()
  }
  // Container query families.
  if variant.has_prefix("@") {
    let (query, _) = split_modifier(variant[1:].to_owned())
    let (base, descending, key) = if query.has_prefix("max-") {
      (65, true, query[4:].to_owned())
    } else if query.has_prefix("min-") {
      (66, false, query[4:].to_owned())
    } else {
      (66, false, query)
    }
    return {
      ..VariantKey::simple(base),
      width: variant_width(key, "--container", theme),
      descending,
    }
  }
  // Breakpoint width families.
  if variant.has_prefix("max-") {
    return {
      ..VariantKey::simple(63),
      width: variant_width(variant[4:].to_owned(), "--breakpoint", theme),
      descending: true,
    }
  }
  if variant.has_prefix("min-") {
    return {
      ..VariantKey::simple(64),
      width: variant_width(variant[4:].to_owned(), "--breakpoint", theme),
    }
  }
  // Functional families ordered by their value.
  let functional = if variant.has_prefix("aria-") {
    Some((52, variant[5:].to_owned()))
  } else if variant.has_prefix("data-") {
    Some((53, variant[5:].to_owned()))
  } else if variant.has_prefix("nth-last-of-type-") {
    Some((57, variant[17:].to_owned()))
  } else if variant.has_prefix("nth-of-type-") {
    Some((56, variant[12:].to_owned()))
  } else if variant.has_prefix("nth-last-") {
    Some((55, variant[9:].to_owned()))
  } else if variant.has_prefix("nth-") {
    Some((54, variant[4:].to_owned()))
  } else if variant.has_prefix("supports-") {
    Some((58, variant[9:].to_owned()))
  } else {
    None
  }
  match functional {
    Some((base, value)) => {
      let arbitrary = value.has_prefix("[")
      return {
        ..VariantKey::simple(base),
        value: Some(value),
        value_arbitrary: arbitrary,
      }
    }
    None => ()
  }
  // Named breakpoints registered from the theme sort with the `min` group.
  if theme.contains("--breakpoint-\{variant}") {
    return {
      ..VariantKey::simple(64),
      width: variant_width(variant, "--breakpoint", theme),
    }
  }
  match static_variant_base(variant) {
    Some(base) => return VariantKey::simple(base)
    None => ()
  }
  // Custom variants are registered after the built-ins, in definition order.
  let mut index = 0
  for name, _ in custom_variants {
    if name == variant {
      return VariantKey::simple(83 + index)
    }
    index += 1
  }
  VariantKey::simple(9000)
}

///|
/// Compare two variant sort keys.
fn VariantKey::compare(self : VariantKey, other : VariantKey) -> Int {
  let by_base = self.base.compare(other.base)
  if by_base != 0 {
    return by_base
  }
  // Same root: arbitrary variants order by their selector.
  match (self.arbitrary, other.arbitrary) {
    (Some(a), Some(b)) => return lexical_compare(a, b)
    _ => ()
  }
  // Grouped media families order by width, unit first then number.
  match (self.width, other.width) {
    (Some((unit_a, number_a)), Some((unit_b, number_b))) => {
      let by_unit = lexical_compare(unit_a, unit_b)
      if by_unit != 0 {
        return by_unit
      }
      let by_number = number_a.compare(number_b)
      return if self.descending { -by_number } else { by_number }
    }
    _ => ()
  }
  // Compound variants defer to their inner variant, then their modifier.
  match (self.inner, other.inner) {
    (Some(inner_a), Some(inner_b)) => {
      let by_inner = inner_a.compare(inner_b)
      if by_inner != 0 {
        return by_inner
      }
      return match (self.modifier, other.modifier) {
        (Some(modifier_a), Some(modifier_b)) =>
          lexical_compare(modifier_a, modifier_b)
        (Some(_), None) => 1
        (None, Some(_)) => -1
        (None, None) => 0
      }
    }
    _ => ()
  }
  // Functional families order by value, named before arbitrary.
  match (self.value, other.value) {
    (Some(value_a), Some(value_b)) => {
      if self.value_arbitrary != other.value_arbitrary {
        return if self.value_arbitrary { 1 } else { -1 }
      }
      return lexical_compare(value_a, value_b)
    }
    _ => ()
  }
  0
}

///|
fn compare_variant_orders(
  a : ArrayView[VariantKey],
  b : ArrayView[VariantKey],
) -> Int {
  let limit = if a.length() < b.length() { a.length() } else { b.length() }
  for index in 0..<limit {
    let comparison = a[index].compare(b[index])
    if comparison != 0 {
      return comparison
    }
  }
  a.length().compare(b.length())
}

///|
fn compare_property_orders(a : ArrayView[Int], b : ArrayView[Int]) -> Int {
  let limit = if a.length() < b.length() { a.length() } else { b.length() }
  for index in 0..<limit {
    let comparison = a[index].compare(b[index])
    if comparison != 0 {
      return comparison
    }
  }
  b.length().compare(a.length())
}

///|
fn compound_state_variant(
  variant : String,
  selector : String,
) -> (String, Bool)? {
  let (kind, raw_state) = if variant.has_prefix("group-") {
    ("group", variant[6:].to_owned())
  } else if variant.has_prefix("peer-") {
    ("peer", variant[5:].to_owned())
  } else {
    return None
  }
  let (state, marker_name) = split_modifier(raw_state)
  let marker = match marker_name {
    Some(name) => escape_class_name("\{kind}/\{name}")
    None => kind
  }
  let marker_selector = ":where(.\{marker})"
  if state.has_prefix("[") && state.has_suffix("]") {
    let arbitrary = decode_arbitrary(state[1:state.length() - 1].to_owned())
    let parent = if arbitrary.contains("&") {
      rewrite_selector_nesting_only(arbitrary, marker_selector)
    } else {
      // Without a nesting marker the state qualifies the group element itself,
      // wrapped so a selector list stays a single compound.
      "\{marker_selector}:is(\{render_selector(parse_selector(arbitrary))})"
    }
    let relation = if kind == "group" { " *" } else { " ~ *" }
    return Some(("\{selector}:is(\{parent}\{relation})", false))
  }
  let state_selector = match state {
    "hover" => ":hover"
    "focus" => ":focus"
    "focus-within" => ":focus-within"
    "focus-visible" => ":focus-visible"
    "active" => ":active"
    "visited" => ":visited"
    "checked" => ":checked"
    "disabled" => ":disabled"
    "first" => ":first-child"
    "last" => ":last-child"
    "odd" => ":nth-child(odd)"
    "even" => ":nth-child(even)"
    has if has.has_prefix("has-") =>
      match has_selector(has[4:].to_owned()) {
        Some(selector) => ":has(\{selector})"
        None => return None
      }
    _ => return None
  }
  let relation = if kind == "group" { " *" } else { " ~ *" }
  let next_selector = "\{selector}:is(\{marker_selector}\{state_selector}\{relation})"
  Some((next_selector, state == "hover"))
}

///|
fn has_selector(state : String) -> String? {
  if state.has_prefix("[") && state.has_suffix("]") {
    let arbitrary = decode_arbitrary(state[1:state.length() - 1].to_owned())
    Some(
      if arbitrary.contains("&") {
        rewrite_selector_nesting_only(arbitrary, "*")
      } else {
        // A plain compound selector is wrapped so a selector list stays one
        // argument, matching upstream `:has(:is(…))`.
        ":is(\{render_selector(parse_selector(arbitrary))})"
      },
    )
  } else {
    match state {
      "checked" => Some(":checked")
      "disabled" => Some(":disabled")
      "hover" => Some(":hover")
      "focus" => Some(":focus")
      "focus-visible" => Some(":focus-visible")
      "active" => Some(":active")
      "empty" => Some(":empty")
      _ => None
    }
  }
}

///|
fn direct_has_variant(variant : String, selector : String) -> String? {
  if !variant.has_prefix("has-") {
    return None
  }
  match has_selector(variant[4:].to_owned()) {
    Some(condition) => Some("\{selector}:has(\{condition})")
    None => None
  }
}

///|
fn normalize_nth_expression(expression : String) -> String? {
  let expression = trim(expression)
  if expression == "2n+1" || expression == "2n + 1" {
    return Some("odd")
  }
  if expression == "2n" {
    return Some("even")
  }
  if is_nonnegative_integer(expression) && expression != "0" {
    return Some(expression)
  }
  if expression.contains("n") {
    return Some(expression)
  }
  None
}

///|
fn nth_variant(variant : String, selector : String) -> String? {
  let (variant, modifier) = split_modifier(variant)
  if modifier is Some(_) {
    return None
  }
  let (prefix, pseudo) = if variant.has_prefix("nth-last-of-type-") {
    ("nth-last-of-type-", "nth-last-of-type")
  } else if variant.has_prefix("nth-of-type-") {
    ("nth-of-type-", "nth-of-type")
  } else if variant.has_prefix("nth-last-") {
    ("nth-last-", "nth-last-child")
  } else if variant.has_prefix("nth-") {
    ("nth-", "nth-child")
  } else {
    return None
  }
  let raw = variant[prefix.length():].to_owned()
  let arbitrary = raw.has_prefix("[") && raw.has_suffix("]")
  let expression = if arbitrary {
    decode_arbitrary(raw[1:raw.length() - 1].to_owned())
  } else {
    raw
  }
  let (formula, of_selector) = match expression.split_once(" of ") {
    Some((formula, of_selector)) =>
      (
        formula.to_owned(),
        Some(render_selector(parse_selector(of_selector.to_owned()))),
      )
    None => (expression, None)
  }
  guard normalize_nth_expression(formula) is Some(normalized_formula) else {
    return None
  }
  let argument = match of_selector {
    Some(of_selector) =>
      if pseudo == "nth-child" || pseudo == "nth-last-child" {
        "\{trim(formula)} of \{of_selector}"
      } else {
        return None
      }
    None => normalized_formula
  }
  Some("\{selector}:\{pseudo}(\{argument})")
}

///|
fn quote_attribute_value(input : String) -> String {
  match input.split_once("=") {
    None => input
    Some((attribute, raw_value)) => {
      let value = trim(raw_value.to_owned())
      if value.has_prefix("\"") || value.has_prefix("'") {
        return input
      }
      if value.length() > 2 && value[value.length() - 2] == ' ' {
        let flag = value[value.length() - 1]
        if flag == 'i' || flag == 'I' || flag == 's' || flag == 'S' {
          return "\{attribute}=\"\{value[:value.length() - 2]}\" \{value[value.length() - 1:]}"
        }
      }
      "\{attribute}=\"\{value}\""
    }
  }
}

///|
fn attribute_variant(variant : String, selector : String) -> String? {
  let (variant, modifier) = split_modifier(variant)
  if modifier is Some(_) {
    return None
  }
  let (prefix, attribute_prefix, named_boolean) = if variant.has_prefix("aria-") {
    ("aria-", "aria-", true)
  } else if variant.has_prefix("data-") {
    ("data-", "data-", false)
  } else {
    return None
  }
  let raw = variant[prefix.length():].to_owned()
  if raw == "" {
    return None
  }
  let arbitrary = raw.has_prefix("[") && raw.has_suffix("]")
  let value = if arbitrary {
    decode_arbitrary(raw[1:raw.length() - 1].to_owned())
  } else {
    raw
  }
  if value == "" || value.contains("[") || value.contains("]") {
    return None
  }
  let attribute = if named_boolean && !arbitrary {
    "\{attribute_prefix}\{value}=\"true\""
  } else {
    "\{attribute_prefix}\{quote_attribute_value(value)}"
  }
  if parse_attribute_selector("[\{attribute}]") is None {
    return None
  }
  Some("\{selector}[\{attribute}]")
}

///|
fn remove_leading_universal(selector : String) -> String {
  if selector.has_prefix("*:") || selector.has_prefix("*[") {
    selector[1:].to_owned()
  } else {
    selector
  }
}

///|
fn remove_leading_universal_list(selector : String) -> String {
  let output = StringBuilder()
  let parts = selector.split(",")
  for index, part in parts {
    if index > 0 {
      output.write_string(", ")
    }
    output.write_string(remove_leading_universal(trim(part.to_owned())))
  }
  output.to_string()
}

///|
fn negate_condition(_name : String, condition : String) -> String {
  let condition = trim(condition)
  if _name == "@container" {
    match condition.find(" (") {
      Some(index) => return "\{condition[:index]} not\{condition[index:]}"
      None => ()
    }
    match condition.find(" not (") {
      Some(index) => return "\{condition[:index]}\{condition[index + 4:]}"
      None => ()
    }
  }
  if condition.has_prefix("not ") {
    condition[4:].to_owned()
  } else {
    "not \{condition}"
  }
}

///|
fn arbitrary_ancestor_selector(inner : String) -> String? {
  if !inner.has_prefix("[") || !inner.has_suffix("]") {
    return None
  }
  let value = trim(decode_arbitrary(inner[1:inner.length() - 1].to_owned()))
  if value == "" ||
    value.has_prefix("@") ||
    value.has_prefix(">") ||
    value.has_prefix("+") ||
    value.has_prefix("~") {
    return None
  }
  let rendered = render_selector(parse_selector(value))
  if rendered == "" {
    return None
  }
  Some(":is(\{rendered})")
}

///|
fn render_candidate(
  theme : Map[String, String],
  custom_utilities : Map[String, Array[CssNode]],
  functional_utilities : Map[String, Array[CssNode]],
  custom_variants : Map[String, CustomVariantTemplate],
  raw : String,
  skip_custom~ : Bool = false,
) -> RenderedCandidate? {
  let candidate_source = match theme_prefix(theme) {
    Some(prefix) => {
      let marker = "\{prefix}:"
      if !raw.has_prefix(marker) {
        return None
      }
      raw[marker.length():].to_owned()
    }
    None => raw
  }
  guard parse_candidate(candidate_source) is Some(candidate) else {
    return None
  }
  if candidate.negative && candidate.base().has_prefix("[") {
    return None
  }
  match
    selector_utility(
      theme,
      candidate.base(),
      candidate.negative,
      candidate.modifier_source(),
    ) {
    Some(utility) =>
      return render_selector_candidate(
        theme, candidate, raw, utility, custom_variants,
      )
    None => ()
  }
  let custom_body = if skip_custom {
    None
  } else {
    match custom_utilities.get(candidate.base()) {
      Some(body) => Some(body)
      None =>
        compile_functional_utility(
          theme,
          candidate.base(),
          candidate.modifier_source(),
          functional_utilities,
        )
    }
  }
  match custom_body {
    Some(body) => {
      guard render_custom_utility_candidate(
          theme, candidate, raw, body, custom_variants,
        )
        is Some(result) else {
        return None
      }
      // A custom `@utility` that shares a built-in's name does not replace it —
      // upstream emits both. Re-render skipping the custom lookup and prepend the
      // built-in's nodes, so e.g. margaui's `@utility table` (which omits
      // `display`) still gets the built-in `display: table`.
      match
        render_candidate(
          theme,
          custom_utilities,
          functional_utilities,
          custom_variants,
          raw,
          skip_custom=true,
        ) {
        Some(builtin) => {
          let nodes = builtin.nodes.copy()
          for node in result.nodes {
            nodes.push(node)
          }
          return Some({
            candidate: result.candidate,
            property_orders: result.property_orders,
            declaration_count: result.declaration_count,
            variant_orders: result.variant_orders,
            nodes,
          })
        }
        None => return Some(result)
      }
    }
    None => ()
  }
  guard compile_base(theme, candidate.base(), candidate.modifier_source())
    is Some(base_declarations) else {
    return None
  }
  let declarations = apply_candidate_value(
    theme,
    base_declarations,
    candidate.negative,
    candidate.modifier_source(),
  )
  let selector = ".\{escape_class_name(raw)}"
  let declaration_nodes = declarations_to_css_nodes(
    declarations,
    important=candidate.important,
  )
  if candidate.base() == "outline-hidden" {
    let span : SourceSpan = { start: 0, end: 0 }
    declaration_nodes.push(
      AtRule(
        name="@media",
        params="(forced-colors: active)",
        nodes=Some([
          Declaration(
            name="outline",
            value="2px solid transparent",
            important=candidate.important,
            span~,
          ),
          Declaration(
            name="outline-offset",
            value="2px",
            important=candidate.important,
            span~,
          ),
        ]),
        span~,
      ),
    )
  }
  if candidate.base().has_prefix("bg-linear-to-") &&
    !candidate.base().contains("[") {
    let span : SourceSpan = { start: 0, end: 0 }
    let direction = declarations[0].value
    declaration_nodes.insert(
      1,
      AtRule(
        name="@supports",
        params="(background-image: linear-gradient(in lab, red, red))",
        nodes=Some([
          Declaration(
            name="--tw-gradient-position",
            value="\{direction} in oklab",
            important=candidate.important,
            span~,
          ),
        ]),
        span~,
      ),
    )
  }
  guard apply_candidate_variants(
      candidate,
      [Rule(selector~, nodes=declaration_nodes, span={ start: 0, end: 0 })],
      selector,
      theme,
      custom_variants,
    )
    is Some(ast_nodes) else {
    return None
  }
  let variant_orders = candidate_variant_orders(
    candidate, theme, custom_variants,
  )
  Some({
    candidate: raw,
    property_orders: {
      let special = if candidate.base().has_prefix("from-") {
        Some(203)
      } else if candidate.base().has_prefix("via-") {
        Some(205)
      } else if candidate.base().has_prefix("to-") {
        Some(207)
      } else {
        None
      }
      let orders : Array[Int] = []
      match special {
        Some(order) => orders.push(order)
        None => ()
      }
      if candidate.base() == "outline-hidden" {
        orders.push(326)
      }
      if special is None {
        for declaration in declarations {
          let declaration_order = property_order(declaration.property)
          if declaration_order != 500 && !orders.contains(declaration_order) {
            orders.push(declaration_order)
          }
        }
      }
      orders.sort()
      orders
    },
    // `perspective-origin-<key>` matches both the `perspective-origin` and the
    // `perspective` root. Upstream compiles those into two single-declaration
    // nodes that the optimizer merges afterwards, so the sort key counts one.
    declaration_count: if candidate.base().has_prefix("perspective-origin-") {
      1
    } else {
      declarations.length()
    },
    variant_orders,
    nodes: ast_nodes,
  })
}

///|
/// Compute the sort key of a compiled node tree the way upstream does.
///
/// Declarations are visited breadth first; a `--tw-sort` declaration replaces
/// the property order and stops further order collection, but every visited
/// declaration still counts.
fn node_property_sort(nodes : ArrayView[CssNode]) -> (Array[Int], Int) {
  let orders : Array[Int] = []
  let mut count = 0
  let mut sorted = false
  let queue : Array[CssNode] = nodes.to_owned()
  let mut index = 0
  while index < queue.length() {
    let node = queue[index]
    index += 1
    match node {
      Declaration(name~, value~, ..) => {
        count += 1
        if sorted {
          continue
        }
        if name == "--tw-sort" {
          let order = property_order(value)
          if order != 500 {
            if !orders.contains(order) {
              orders.push(order)
            }
            sorted = true
          }
          continue
        }
        let order = property_order(name)
        if order != 500 && !orders.contains(order) {
          orders.push(order)
        }
      }
      Rule(nodes=children, ..)
      | AtRule(nodes=Some(children), ..)
      | Context(nodes=children, ..) =>
        for child in children {
          queue.push(child)
        }
      _ => ()
    }
  }
  orders.sort()
  (orders, count)
}

///|
/// Mark every declaration of a compiled node tree as important.
fn mark_nodes_important(nodes : ArrayView[CssNode]) -> Array[CssNode] {
  nodes.map(fn(node) {
    match node {
      Declaration(name~, value~, span~, ..) =>
        Declaration(name~, value~, important=true, span~)
      Rule(selector~, nodes=children, span~) =>
        Rule(selector~, nodes=mark_nodes_important(children), span~)
      AtRule(name~, params~, nodes=Some(children), span~) =>
        AtRule(
          name~,
          params~,
          nodes=Some(mark_nodes_important(children)),
          span~,
        )
      // `at-root` content belongs to the stylesheet, not to the candidate.
      _ => node
    }
  })
}

///|
/// Render a candidate whose utility comes from `@utility`.
fn render_custom_utility_candidate(
  theme : Map[String, String],
  candidate : ParsedCandidate,
  raw : String,
  body : Array[CssNode],
  custom_variants : Map[String, CustomVariantTemplate],
) -> RenderedCandidate? {
  let selector = ".\{escape_class_name(raw)}"
  let children = if candidate.important {
    mark_nodes_important(body)
  } else {
    body.copy()
  }
  let (property_orders, declaration_count) = node_property_sort(children)
  guard apply_candidate_variants(
      candidate,
      [Rule(selector~, nodes=children, span={ start: 0, end: 0 })],
      selector,
      theme,
      custom_variants,
    )
    is Some(ast_nodes) else {
    return None
  }
  Some({
    candidate: raw,
    property_orders,
    declaration_count,
    variant_orders: candidate_variant_orders(candidate, theme, custom_variants),
    nodes: ast_nodes,
  })
}

///|
/// Apply every variant of a candidate to already-compiled nodes.
fn apply_candidate_variants(
  candidate : ParsedCandidate,
  nodes : Array[CssNode],
  selector : String,
  theme : Map[String, String],
  custom_variants : Map[String, CustomVariantTemplate],
) -> Array[CssNode]? {
  let mut ast_nodes = nodes
  let mut ast_selector = selector
  for variant in candidate.variants {
    guard apply_variant_to_nodes(
        variant.source(),
        ast_nodes,
        ast_selector,
        theme,
        custom_variants,
        [],
      )
      is Some((next_nodes, next_selector)) else {
      return None
    }
    ast_nodes = next_nodes
    ast_selector = next_selector
  }
  Some(ast_nodes)
}

///|
fn candidate_variant_orders(
  candidate : ParsedCandidate,
  theme : Map[String, String],
  custom_variants : Map[String, CustomVariantTemplate],
) -> Array[VariantKey] {
  let keys : Array[VariantKey] = []
  for variant in candidate.variants {
    let key = variant_key(variant.source(), theme, custom_variants)
    if !keys.contains(key) {
      keys.push(key)
    }
  }
  keys.sort_by(fn(a, b) { b.compare(a) })
  keys
}

///|
/// Render a candidate whose utility emits a nested selector.
///
/// The nested selector is flattened against the candidate selector up front so
/// that variant application, which rewrites selector strings, keeps working on
/// both the outer and the nested form at once.
fn render_selector_candidate(
  theme : Map[String, String],
  candidate : ParsedCandidate,
  raw : String,
  utility : SelectorUtility,
  custom_variants : Map[String, CustomVariantTemplate],
) -> RenderedCandidate? {
  let selector = ".\{escape_class_name(raw)}"
  let nested = replace_all(utility.nested_selector, "&", selector)
  let declaration_nodes = declarations_to_css_nodes(
    utility.declarations,
    important=candidate.important,
  )
  guard apply_candidate_variants(
      candidate,
      [
        Rule(selector=nested, nodes=declaration_nodes, span={ start: 0, end: 0 }),
      ],
      selector,
      theme,
      custom_variants,
    )
    is Some(ast_nodes) else {
    return None
  }
  let orders : Array[Int] = []
  let sort_order = if utility.sort_key == "" {
    500
  } else {
    property_order(utility.sort_key)
  }
  if sort_order != 500 {
    orders.push(sort_order)
  } else {
    for declaration in utility.declarations {
      let declaration_order = property_order(declaration.property)
      if declaration_order != 500 && !orders.contains(declaration_order) {
        orders.push(declaration_order)
      }
    }
    orders.sort()
  }
  Some({
    candidate: raw,
    property_orders: orders,
    // Upstream counts the `--tw-sort` declaration it strips later on.
    declaration_count: utility.declarations.length() +
    (if utility.sort_key == "" { 0 } else { 1 }),
    variant_orders: candidate_variant_orders(candidate, theme, custom_variants),
    nodes: ast_nodes,
  })
}

///|
