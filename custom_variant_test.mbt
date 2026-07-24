///|
async test "selector shorthand @custom-variant applies to utilities" {
  let compiler = @tailwindcss.compile(
    (
      #|@custom-variant theme-midnight (&:where([data-theme="midnight"] *));
      #|@tailwind utilities;
      #|
    ),
  )
  inspect(
    compiler.build(["theme-midnight:flex"]),
    content=(
      #|.theme-midnight\:flex:where([data-theme="midnight"] *) {
      #|  display: flex;
      #|}
      #|
    ),
  )
}

///|
async test "block @custom-variant supports selector and at-rule slots" {
  let compiler = @tailwindcss.compile(
    (
      #|@custom-variant selected {
      #|  &[data-selected] { @slot; }
      #|}
      #|@custom-variant any-hover {
      #|  @media (any-hover: hover) { @slot; }
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  inspect(
    compiler.build(["selected:flex", "any-hover:block"]),
    content=(
      #|.selected\:flex[data-selected] {
      #|  display: flex;
      #|}
      #|@media (any-hover: hover) {
      #|  .any-hover\:block {
      #|    display: block;
      #|  }
      #|}
      #|
    ),
  )
}

///|
async test "block @custom-variant emits multiple selector slots" {
  let compiler = @tailwindcss.compile(
    (
      #|@custom-variant hocus {
      #|  &:hover { @slot; }
      #|  &:focus { @slot; }
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  inspect(
    compiler.build(["hocus:flex"]),
    content=(
      #|.hocus\:flex:hover {
      #|  display: flex;
      #|}
      #|.hocus\:flex:focus {
      #|  display: flex;
      #|}
      #|
    ),
  )
}

///|
async test "block @custom-variant nests selectors and at-rules" {
  let compiler = @tailwindcss.compile(
    (
      #|@custom-variant interactive {
      #|  @media (hover: hover) {
      #|    &[data-ready] {
      #|      &:hover { @slot; }
      #|    }
      #|  }
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  inspect(
    compiler.build(["interactive:flex"]),
    content=(
      #|@media (hover: hover) {
      #|  .interactive\:flex[data-ready]:hover {
      #|    display: flex;
      #|  }
      #|}
      #|
    ),
  )
}

///|
async test "block @custom-variant emits declarations around a nested slot" {
  let compiler = @tailwindcss.compile(
    (
      #|@custom-variant ready-child {
      #|  &[data-ready] {
      #|    outline: 1px solid;
      #|    & > * { @slot; }
      #|  }
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build(["ready-child:flex"])
  assert_true(
    output.contains(
      (
        #|.ready-child\:flex[data-ready] {
        #|  outline: 1px solid;
        #|  & > * {
        #|    display: flex;
        #|  }
        #|}
      ),
    ),
  )
}

///|
async test "block @custom-variant composes built-in and later custom variants" {
  let compiler = @tailwindcss.compile(
    (
      #|@custom-variant hocus {
      #|  @variant hover {
      #|    @variant focus { @slot; }
      #|  }
      #|}
      #|@custom-variant aliased {
      #|  @variant custom-hover { @slot; }
      #|}
      #|@custom-variant custom-hover (&:hover);
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build(["hocus:flex", "aliased:block"])
  assert_true(
    output.contains(
      (
        #|@media (hover: hover) {
        #|  .hocus\:flex:hover:focus {
        #|    display: flex;
        #|  }
        #|}
      ),
    ),
  )
  assert_true(
    output.contains(
      (
        #|.aliased\:block:hover {
        #|  display: block;
        #|}
      ),
    ),
  )
}
