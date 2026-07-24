///|
async test "compile static utilities" {
  let compiler = @tailwindcss.compile("@tailwind utilities;")
  inspect(
    compiler.build(["flex", "hidden"]),
    content=(
      #|.flex {
      #|  display: flex;
      #|}
      #|.hidden {
      #|  display: none;
      #|}
      #|
    ),
  )
}

///|
async test "compile accessibility and layout primitive utilities" {
  let compiler = @tailwindcss.compile("@tailwind utilities;")
  let output = compiler.build([
    "sr-only", "not-sr-only", "pointer-events-none", "isolate", "float-start", "clear-both",
    "box-border", "table-cell", "field-sizing-content", "flex-initial", "basis-full",
    "caption-bottom", "border-separate",
  ])
  assert_true(output.contains(".sr-only"))
  assert_true(output.contains("clip-path: inset(50%)"))
  assert_true(output.contains(".not-sr-only"))
  assert_true(output.contains("pointer-events: none"))
  assert_true(output.contains("isolation: isolate"))
  assert_true(output.contains("float: inline-start"))
  assert_true(output.contains("clear: both"))
  assert_true(output.contains("box-sizing: border-box"))
  assert_true(output.contains("display: table-cell"))
  assert_true(output.contains("field-sizing: content"))
  assert_true(output.contains("flex: 0 auto"))
  assert_true(output.contains("flex-basis: 100%"))
  assert_true(output.contains("caption-side: bottom"))
  assert_true(output.contains("border-collapse: separate"))
}

///|
async test "compile logical spacing inset and special sizing utilities" {
  let compiler = @tailwindcss.compile(
    "@theme { --spacing: 0.25rem; }\n@tailwind utilities;",
  )
  let output = compiler.build([
    "ms-4", "pbe-2", "inset-full", "-inset-s-2", "top-auto", "w-screen", "max-w-none",
    "h-lh", "size-full", "size-3",
  ])
  assert_true(output.contains("margin-inline-start: calc(var(--spacing) * 4)"))
  assert_true(output.contains("padding-block-end: calc(var(--spacing) * 2)"))
  assert_true(output.contains("inset: 100%"))
  assert_true(output.contains("inset-inline-start: calc(var(--spacing) * -2)"))
  assert_true(output.contains("top: auto"))
  assert_true(output.contains("width: 100vw"))
  assert_true(output.contains("max-width: none"))
  assert_true(output.contains("height: 1lh"))
  assert_true(output.contains("width: 100%"))
  assert_true(output.contains("height: 100%"))
}

///|
async test "compile text flow list and vertical alignment utilities" {
  let compiler = @tailwindcss.compile("@tailwind utilities;")
  let output = compiler.build([
    "text-ellipsis", "hyphens-auto", "whitespace-break-spaces", "text-balance", "break-normal",
    "wrap-anywhere", "list-inside", "list-decimal", "scrollbar-gutter-both", "align-text-top",
  ])
  assert_true(output.contains("text-overflow: ellipsis"))
  assert_true(output.contains("-webkit-hyphens: auto"))
  assert_true(output.contains("white-space: break-spaces"))
  assert_true(output.contains("text-wrap: balance"))
  assert_true(output.contains("overflow-wrap: normal"))
  assert_true(output.contains("word-break: normal"))
  assert_true(output.contains("overflow-wrap: anywhere"))
  assert_true(output.contains("list-style-position: inside"))
  assert_true(output.contains("list-style-type: decimal"))
  assert_true(output.contains("scrollbar-gutter: stable both-edges"))
  assert_true(output.contains("vertical-align: text-top"))
}

///|
async test "compile aspect object position and alignment utilities" {
  let compiler = @tailwindcss.compile(
    "@theme { --aspect-card: 4 / 3; --object-position-hero: 20% 30%; }\n@tailwind utilities;",
  )
  let output = compiler.build([
    "aspect-square", "aspect-[3/2]", "aspect-card", "object-center", "object-[25%_75%]",
    "object-hero", "items-baseline-last", "content-between", "justify-stretch", "place-items-center",
    "self-baseline", "justify-self-end",
  ])
  assert_true(output.contains("aspect-ratio: 1 / 1"))
  assert_true(output.contains("aspect-ratio: 3/2"))
  assert_true(output.contains("aspect-ratio: var(--aspect-card)"))
  assert_true(output.contains("object-position: center"))
  assert_true(output.contains("object-position: 25% 75%"))
  assert_true(output.contains("object-position: var(--object-position-hero)"))
  assert_true(output.contains("align-items: last baseline"))
  assert_true(output.contains("align-content: space-between"))
  assert_true(output.contains("justify-content: stretch"))
  assert_true(output.contains("place-items: center"))
  assert_true(output.contains("align-self: baseline"))
  assert_true(output.contains("justify-self: flex-end"))
}

///|
async test "compile overflow scrolling selection and resize utilities" {
  let compiler = @tailwindcss.compile("@tailwind utilities;")
  let output = compiler.build([
    "overflow-x-clip", "overflow-y-auto", "overscroll-contain", "overscroll-x-none",
    "scroll-smooth", "scrollbar-thin", "select-none", "resize-x", "snap-none", "snap-center",
    "snap-always",
  ])
  assert_true(output.contains("overflow-x: clip"))
  assert_true(output.contains("overflow-y: auto"))
  assert_true(output.contains("overscroll-behavior: contain"))
  assert_true(output.contains("overscroll-behavior-x: none"))
  assert_true(output.contains("scroll-behavior: smooth"))
  assert_true(output.contains("scrollbar-width: thin"))
  assert_true(output.contains("-webkit-user-select: none"))
  assert_true(output.contains("user-select: none"))
  assert_true(output.contains("resize: horizontal"))
  assert_true(output.contains("scroll-snap-type: none"))
  assert_true(output.contains("scroll-snap-align: center"))
  assert_true(output.contains("scroll-snap-stop: always"))
}

///|
async test "compile cursor appearance touch and interaction color utilities" {
  let compiler = @tailwindcss.compile(
    "@theme { --color-brand: #123456; --cursor-precision: crosshair; }\n@tailwind utilities;",
  )
  let output = compiler.build([
    "cursor-pointer", "cursor-precision", "cursor-[url(hand.cur),_pointer]", "appearance-none",
    "touch-manipulation", "accent-auto", "accent-brand", "caret-[#abcdef]", "backface-hidden",
    "transform-view",
  ])
  assert_true(output.contains("cursor: pointer"))
  assert_true(output.contains("cursor: var(--cursor-precision)"))
  assert_true(output.contains("cursor: url(hand.cur), pointer"))
  assert_true(output.contains("appearance: none"))
  assert_true(output.contains("touch-action: manipulation"))
  assert_true(output.contains("accent-color: auto"))
  assert_true(output.contains("accent-color: var(--color-brand)"))
  assert_true(output.contains("caret-color: #abcdef"))
  assert_true(output.contains("backface-visibility: hidden"))
  assert_true(output.contains("transform-box: view-box"))
}

///|
async test "compile grid template auto track and flow utilities" {
  let compiler = @tailwindcss.compile(
    "@theme { --grid-template-columns-dashboard: 12rem 1fr; }\n@tailwind utilities;",
  )
  let output = compiler.build([
    "grid-cols-3", "grid-cols-[200px_1fr]", "grid-cols-dashboard", "grid-rows-subgrid",
    "auto-cols-fr", "auto-rows-[minmax(0,2fr)]", "grid-flow-row-dense", "grid-cols-0",
  ])
  assert_true(
    output.contains("grid-template-columns: repeat(3, minmax(0, 1fr))"),
  )
  assert_true(output.contains("grid-template-columns: 200px 1fr"))
  assert_true(
    output.contains(
      "grid-template-columns: var(--grid-template-columns-dashboard)",
    ),
  )
  assert_true(output.contains("grid-template-rows: subgrid"))
  assert_true(output.contains("grid-auto-columns: minmax(0, 1fr)"))
  assert_true(output.contains("grid-auto-rows: minmax(0,2fr)"))
  assert_true(output.contains("grid-auto-flow: row dense"))
  assert_false(output.contains(".grid-cols-0"))
}

///|
async test "compile grid item placement utilities" {
  let compiler = @tailwindcss.compile(
    "@theme { --grid-column-sidebar: 1 / 3; --grid-row-start-main: 2; }\n@tailwind utilities;",
  )
  let output = compiler.build([
    "col-span-3", "col-span-full", "col-start-2", "-col-end-4", "col-sidebar", "row-span-[2]",
    "row-start-main", "row-end-auto", "row-0",
  ])
  assert_true(output.contains("grid-column: span 3 / span 3"))
  assert_true(output.contains("grid-column: 1 / -1"))
  assert_true(output.contains("grid-column-start: 2"))
  assert_true(output.contains("grid-column-end: calc(4 * -1)"))
  assert_true(output.contains("grid-column: var(--grid-column-sidebar)"))
  assert_true(output.contains("grid-row: span 2 / span 2"))
  assert_true(output.contains("grid-row-start: var(--grid-row-start-main)"))
  assert_true(output.contains("grid-row-end: auto"))
  assert_false(output.contains(".row-0"))
}

///|
async test "compile theme-backed utilities" {
  let compiler = @tailwindcss.compile(
    "@theme { --color-brand: #123456; --spacing: 0.5rem; }\n@tailwind utilities;",
  )
  inspect(
    compiler.build(["bg-brand", "p-4"]),
    content=(
      #|:root, :host {
      #|  --color-brand: #123456;
      #|  --spacing: 0.5rem;
      #|}
      #|.bg-brand {
      #|  background-color: var(--color-brand);
      #|}
      #|.p-4 {
      #|  padding: calc(var(--spacing) * 4);
      #|}
      #|
    ),
  )
}

///|
async test "compiler accumulates candidates" {
  let compiler = @tailwindcss.compile("@tailwind utilities;")
  ignore(compiler.build(["block"]))
  let output = compiler.build(["relative"])
  assert_true(output.contains(".block"))
  assert_true(output.contains(".relative"))
}

///|
async test "unknown candidates are ignored" {
  let compiler = @tailwindcss.compile("@tailwind utilities;")
  inspect(compiler.build(["definitely-not-a-utility"]), content="")
}

///|
async test "compile theme-backed and arbitrary container variants" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme { --container-lg: 1024px; }
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build([
    "@lg/sidebar:flex", "@min-[456px]:block", "@max-lg:grid",
  ])
  assert_true(
    output.contains(
      (
        #|@container sidebar (width >= 1024px) {
        #|  .\@lg\/sidebar\:flex {
        #|    display: flex;
        #|  }
        #|}
      ),
    ),
  )
  assert_true(output.contains("@container (width >= 456px)"))
  assert_true(output.contains("@container (width < 1024px)"))
}

///|
async test "compile minimum and maximum responsive variants" {
  let compiler = @tailwindcss.compile(
    "@theme { --breakpoint-sm: 640px; }\n@tailwind utilities;",
  )
  let output = compiler.build([
    "min-sm:flex", "max-sm:block", "min-[700px]:grid", "max-[500px]:hidden", "not-min-sm:flex",
  ])
  assert_true(output.contains("@media (width >= 640px)"))
  assert_true(output.contains("@media (width < 640px)"))
  assert_true(output.contains("@media (width >= 700px)"))
  assert_true(output.contains("@media (width < 500px)"))
  assert_true(output.contains("@media not (width >= 640px)"))
}

///|
async test "container variants sort maximum descending before minimum ascending" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme {
      #|  --container-lg: 1024px;
      #|  --container-wide: 1440px;
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build([
    "@min-[456px]:block", "@wide:flex", "@max-lg:grid",
  ])
  guard output.find("@container (width < 1024px)") is Some(maximum) else {
    fail("missing maximum container query")
  }
  guard output.find("@container (width >= 456px)") is Some(small) else {
    fail("missing small minimum container query")
  }
  guard output.find("@container (width >= 1440px)") is Some(wide) else {
    fail("missing wide minimum container query")
  }
  assert_true(maximum < small && small < wide)
}

///|
async test "compile group and peer compound state variants" {
  let compiler = @tailwindcss.compile("@tailwind utilities;")
  let output = compiler.build(["group-hover:flex", "peer-focus:block"])
  assert_true(
    output.contains(
      (
        #|@media (hover: hover) {
        #|  .group-hover\:flex:is(:where(.group):hover *) {
        #|    display: flex;
        #|  }
        #|}
      ),
    ),
  )
  assert_true(
    output.contains(
      (
        #|.peer-focus\:block:is(:where(.peer):focus ~ *) {
        #|  display: block;
        #|}
      ),
    ),
  )
}

///|
async test "compile direct, group, peer, arbitrary, and named has variants" {
  let compiler = @tailwindcss.compile("@tailwind utilities;")
  let output = compiler.build([
    "has-checked:flex", "has-[:focus]:block", "group-has-checked/sidebar:grid", "peer-has-disabled/item:hidden",
    "group-[&:focus]/form:flex",
  ])
  assert_true(output.contains(".has-checked\\:flex:has(:checked)"))
  assert_true(output.contains(".has-\\[\\:focus\\]\\:block:has(:is(:focus))"))
  assert_true(output.contains(":is(:where(.group\\/sidebar):has(:checked) *)"))
  assert_true(output.contains(":is(:where(.peer\\/item):has(:disabled) ~ *)"))
  assert_true(output.contains(":is(:where(.group\\/form):focus *)"))
}

///|
async test "compile nth structural variants and selector clauses" {
  let compiler = @tailwindcss.compile("@tailwind utilities;")
  let output = compiler.build([
    "nth-3:flex", "nth-[2n+1_of_.item]:block", "nth-last-[2n]:grid", "nth-of-type-2:hidden",
    "nth-foo:flex", "nth-3/nope:flex",
  ])
  assert_true(output.contains(".nth-3\\:flex:nth-child(3)"))
  assert_true(
    output.contains(
      ".nth-\\[2n\\+1_of_\\.item\\]\\:block:nth-child(2n+1 of .item)",
    ),
  )
  assert_true(output.contains(":nth-last-child(even)"))
  assert_true(output.contains(":nth-of-type(2)"))
  assert_false(output.contains("nth-foo"))
  assert_false(output.contains("nth-3\\/nope"))
}

///|
async test "compile aria and data attribute variants" {
  let compiler = @tailwindcss.compile("@tailwind utilities;")
  let output = compiler.build([
    "aria-checked:flex", "aria-[sort=ascending]:block", "aria-[label='Save']:grid",
    "data-[state=open]:hidden", "data-active:flex", "data-[mode=dark_i]:block", "aria-checked/nope:flex",
  ])
  assert_true(output.contains("[aria-checked=\"true\"]"))
  assert_true(output.contains("[aria-sort=\"ascending\"]"))
  assert_true(output.contains("[aria-label='Save']"))
  assert_true(output.contains("[data-state=\"open\"]"))
  assert_true(output.contains("[data-active]"))
  assert_true(output.contains("[data-mode=\"dark\" i]"))
  assert_false(output.contains("aria-checked\\/nope"))
}

///|
async test "compile selector-compatible not and in compound variants" {
  let compiler = @tailwindcss.compile("@tailwind utilities;")
  let output = compiler.build([
    "not-focus:flex", "not-has-checked:block", "not-aria-selected:grid", "not-nth-2:hidden",
    "in-data-visible:flex", "not-in-data-visible:block", "not-hover:grid", "supports-[display:grid]:flex",
    "supports-grid:block", "not-supports-grid:hidden", "in-[.group]:flex", "in-[p]:block",
    "not-in-[.panel]:grid",
  ])
  assert_true(output.contains(".not-focus\\:flex:not(:focus)"))
  assert_true(output.contains(".not-has-checked\\:block:not(:has(:checked))"))
  assert_true(
    output.contains(".not-aria-selected\\:grid:not([aria-selected=\"true\"])"),
  )
  assert_true(output.contains(".not-nth-2\\:hidden:not(:nth-child(2))"))
  assert_true(output.contains(":where([data-visible]) .in-data-visible\\:flex"))
  assert_true(
    output.contains(
      ".not-in-data-visible\\:block:not(:where([data-visible]) *)",
    ),
  )
  assert_true(output.contains(".not-hover\\:grid:not(:hover)"))
  assert_true(output.contains("@media not (hover: hover)"))
  assert_true(output.contains("@supports (display:grid)"))
  assert_true(output.contains("@supports (grid: var(--tw))"))
  assert_true(output.contains("@supports not (grid: var(--tw))"))
  assert_true(output.contains(":where(:is(.group)) .in-\\[\\.group\\]\\:flex"))
  assert_true(output.contains(":where(:is(p)) .in-\\[p\\]\\:block"))
  assert_true(
    output.contains(".not-in-\\[\\.panel\\]\\:grid:not(:where(:is(.panel)) *)"),
  )
}

///|
async test "compile extended state direction and environment variants" {
  let compiler = @tailwindcss.compile("@tailwind utilities;")
  let output = compiler.build([
    "placeholder-shown:flex", "in-range:block", "inert:grid", "rtl:hidden", "starting:flex",
    "contrast-more:block", "forced-colors:grid", "pointer-fine:hidden", "noscript:flex",
  ])
  assert_true(output.contains(":placeholder-shown"))
  assert_true(output.contains(":in-range"))
  assert_true(output.contains(":is([inert], [inert] *)"))
  assert_true(
    output.contains(":where(:dir(rtl), [dir=\"rtl\"], [dir=\"rtl\"] *)"),
  )
  assert_true(output.contains("@starting-style"))
  assert_true(output.contains("@media (prefers-contrast: more)"))
  assert_true(output.contains("@media (forced-colors: active)"))
  assert_true(output.contains("@media (pointer: fine)"))
  assert_true(output.contains("@media (scripting: none)"))
}

///|
async test "compile pseudo-element and user validation variants" {
  let compiler = @tailwindcss.compile("@tailwind utilities;")
  let output = compiler.build([
    "first-letter:flex", "first-line:flex", "marker:flex", "selection:flex", "file:flex",
    "placeholder:flex", "backdrop:flex", "details-content:flex", "before:flex", "after:flex",
    "user-valid:flex", "user-invalid:flex",
  ])
  assert_true(output.contains(".first-letter\\:flex::first-letter"))
  assert_true(output.contains(".marker\\:flex ::-webkit-details-marker"))
  assert_true(output.contains(".selection\\:flex ::selection"))
  assert_true(output.contains(".file\\:flex::file-selector-button"))
  assert_true(output.contains(".details-content\\:flex::details-content"))
  assert_true(output.contains(".before\\:flex::before"))
  assert_true(output.contains("content: var(--tw-content);"))
  assert_true(output.contains("@property --tw-content"))
  assert_true(output.contains(".user-valid\\:flex:user-valid"))
  assert_true(output.contains(".user-invalid\\:flex:user-invalid"))
}

///|
async test "compile nested compound variants and sort equivalent stacks" {
  let compiler = @tailwindcss.compile(
    "@custom-variant hocus (&:hover, &:focus);\n@tailwind utilities;",
  )
  let output = compiler.build([
    "active:focus:flex", "focus:active:flex", "group-not-hover:flex", "peer-not-checked:block",
    "not-group-hover:grid", "group-has-checked/foo:flex", "group-hocus:flex",
  ])
  assert_true(
    output.find(".active\\:focus\\:flex") <
    output.find(".focus\\:active\\:flex"),
  )
  assert_false(output.contains(".group-not-hover\\:flex"))
  assert_true(output.contains(":where(.peer):not(:checked) ~ *"))
  assert_true(output.contains(":not(:is(:where(.group):hover *))"))
  assert_true(output.contains(":where(.group\\/foo):has(:checked) *"))
  assert_true(
    output.contains(":is(:where(.group):hover, :where(.group):focus) *"),
  )
}
