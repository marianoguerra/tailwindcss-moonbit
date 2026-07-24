///|
test "candidate compilation builds CSS AST nodes before rendering" {
  let theme : Map[String, String] = {
    "--breakpoint-sm": "40rem",
    "--container-lg": "64rem",
  }
  let empty_declarations : Map[String, Array[CssNode]] = Map([])
  let custom_variants : Map[String, CustomVariantTemplate] = Map([])
  guard render_candidate(
      theme, empty_declarations, empty_declarations, custom_variants, "hover:flex",
    )
    is Some(
      {
        nodes: [
          AtRule(
            name="@media",
            params="(hover: hover)",
            nodes=Some(
              [
                Rule(
                  selector=".hover\\:flex:hover",
                  nodes=[Declaration(name="display", value="flex", ..)],
                  ..
                ),
              ]
            ),
            ..
          ),
        ],
        ..,
      }
    ) else {
    fail("expected a media/rule/declaration AST")
  }
  guard render_candidate(
      theme, empty_declarations, empty_declarations, custom_variants, "sm:flex",
    )
    is Some(
      { nodes: [AtRule(name="@media", params="(width >= 40rem)", ..)], .. }
    ) else {
    fail("expected a responsive at-rule AST")
  }
  guard render_candidate(
      theme, empty_declarations, empty_declarations, custom_variants, "@lg:flex",
    )
    is Some(
      { nodes: [AtRule(name="@container", params="(width >= 64rem)", ..)], .. }
    ) else {
    fail("expected a container at-rule AST")
  }
}

///|
test "important and fallback declarations remain structured nodes" {
  let theme : Map[String, String] = { "--color-brand": "#123456" }
  let empty_declarations : Map[String, Array[CssNode]] = Map([])
  let custom_variants : Map[String, CustomVariantTemplate] = Map([])
  guard render_candidate(
      theme, empty_declarations, empty_declarations, custom_variants, "text-brand/50!",
    )
    is Some(
      {
        nodes: [
          Rule(
            nodes=[
              Declaration(name="color", important=true, ..),
              AtRule(
                name="@supports",
                nodes=Some([Declaration(name="color", important=true, ..)]),
                ..
              ),
            ],
            ..
          ),
        ],
        ..,
      }
    ) else {
    fail("expected fallback and advanced declarations as AST nodes")
  }
}
