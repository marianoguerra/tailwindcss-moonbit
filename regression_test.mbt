// Regression fixtures for drift discovered during development.
//
// Each test pins a specific behaviour that once diverged from the upstream
// compiler, so a future change cannot silently reintroduce the bug.

///|
/// Assert that each needle occurs in order within the haystack.
fn assert_in_order(haystack : String, needles : ArrayView[String]) -> Unit {
  let mut cursor = 0
  for needle in needles {
    let mut found = -1
    let limit = haystack.length() - needle.length()
    for start in cursor..<=limit {
      if haystack[start:start + needle.length()] == needle {
        found = start
        break
      }
    }
    if found < 0 {
      abort("expected \{needle} after position \{cursor}")
    }
    cursor = found + needle.length()
  }
}

///|
async test "arbitrary variants qualify the element with :is()" {
  let compiler = @tailwindcss.compile("@tailwind utilities;")
  let output = compiler.build([
    "[.x]:flex", "[&.x]:flex", "[[data-x]]:flex", "group-[.x]:flex", "has-[a]:flex",
  ])
  assert_true(output.contains(".\\[\\.x\\]\\:flex:is(.x)"))
  assert_true(output.contains(".\\[\\&\\.x\\]\\:flex.x"))
  assert_true(output.contains(".\\[\\[data-x\\]\\]\\:flex:is([data-x])"))
  assert_true(output.contains(":is(:where(.group):is(.x) *)"))
  assert_true(output.contains(".has-\\[a\\]\\:flex:has(:is(a))"))
}

///|
async test "media variants sort by width, max before min" {
  let compiler = @tailwindcss.compile(
    "@theme { --breakpoint-sm: 640px; --breakpoint-md: 768px; --breakpoint-lg: 1024px; }\n@tailwind utilities;",
  )
  let output = compiler.build([
    "sm:flex", "lg:flex", "max-sm:flex", "max-lg:flex", "min-sm:flex",
  ])
  assert_in_order(output, [
    "(width < 1024px)", "(width < 640px)", "(width >= 640px)", "(width >= 1024px)",
  ])
}

///|
async test "compound variants sort by their root then inner variant" {
  let compiler = @tailwindcss.compile(
    "@theme { --breakpoint-md: 768px; }\n@tailwind utilities;",
  )
  let output = compiler.build([
    "group-hover:flex", "hover:flex", "md:flex", "not-hover:flex", "first:flex",
  ])
  // not (root 3) < group (root 4) < first (16) < hover (43) < md (64).
  assert_in_order(output, [
    "not-hover", "group-hover", "first\\:flex", "hover\\:flex", "md\\:flex",
  ])
}

///|
async test "ease keyword yields to a theme timing function" {
  let themed = @tailwindcss.compile(
    "@theme { --ease-linear: cubic-bezier(0, 0, 1, 1); }\n@tailwind utilities;",
  ).build(["ease-linear"])
  assert_true(themed.contains("--tw-ease: var(--ease-linear)"))
  let bare = @tailwindcss.compile("@tailwind utilities;").build(["ease-linear"])
  assert_true(bare.contains("--tw-ease: linear"))
}

///|
priv struct FuzzState {
  mut seed : UInt64
}

///|
fn FuzzState::pick(self : FuzzState, pieces : ArrayView[String]) -> String {
  self.seed = self.seed * 6364136223846793005UL + 1442695040888963407UL
  pieces[(self.seed >> 33).to_int() % pieces.length()]
}

///|
async test "compile and build never panic on random candidates" {
  let compiler = @tailwindcss.compile(
    "@theme { --spacing: 0.25rem; --color-brand: #123456; --breakpoint-md: 768px; }\n@tailwind utilities;",
  )
  let pieces = [
    "hover:", "md:", "group-[.x]:", "has-[a]:", "not-", "[&_p]:", "aria-[x=y]:",
    "-", "!", "bg-brand", "m-[", "]", "text-brand/", "50", "w-1/2", "space-x-4",
    "flex", "(", ")", "/", "\\", "[color:red]", "divide-y-", "@md:",
  ]
  let state : FuzzState = { seed: 0x1357_9bdf_2468_ace0 }
  let candidates : Array[String] = []
  for _ in 0..<500 {
    let builder = StringBuilder()
    let count = {
      state.seed = state.seed * 6364136223846793005UL + 1442695040888963407UL
      (state.seed >> 40).to_int() % 5 + 1
    }
    for _ in 0..<count {
      builder.write_string(state.pick(pieces))
    }
    candidates.push(builder.to_string())
  }
  // Unknown or malformed candidates are ignored; the point is that no input
  // makes the build path panic.
  let _ = compiler.build(candidates)
}
