// Public-API property tests: candidate discovery order and incremental builds
// must not change the generated CSS.

///|
priv struct Lcg {
  mut state : UInt64
}

///|
fn Lcg::new(seed : UInt64) -> Lcg {
  { state: seed }
}

///|
fn Lcg::below(self : Lcg, bound : Int) -> Int {
  self.state = self.state * 6364136223846793005UL + 1442695040888963407UL
  ((self.state >> 33).to_int() % bound + bound) % bound
}

///|
/// Fisher-Yates shuffle driven by the deterministic generator.
fn shuffle(items : Array[String], rng : Lcg) -> Array[String] {
  let out = items.copy()
  let mut index = out.length() - 1
  while index > 0 {
    let swap = rng.below(index + 1)
    let temporary = out[index]
    out[index] = out[swap]
    out[swap] = temporary
    index -= 1
  }
  out
}

///|
let ordering_stylesheet : String =
  #|@theme {
  #|  --breakpoint-sm: 640px;
  #|  --breakpoint-md: 768px;
  #|  --breakpoint-lg: 1024px;
  #|  --color-brand: #123456;
  #|  --spacing: 0.25rem;
  #|}
  #|@tailwind utilities;
  #|

///|
let ordering_candidates : Array[String] = [
  "dark:flex", "sm:flex", "md:flex", "lg:flex", "max-sm:flex", "min-sm:flex", "hover:bg-brand",
  "focus:flex", "group-hover:flex", "peer-focus:flex", "has-[a]:flex", "not-hover:flex",
  "aria-checked:flex", "data-[x=y]:flex", "@sm:flex", "[&_p]:flex", "first:flex",
  "before:flex", "m-4", "p-2", "bg-brand/50", "space-x-4", "divide-y", "text-brand",
  "w-1/2",
]

///|
async test "candidate discovery order does not change the output" {
  let reference = @tailwindcss.compile(ordering_stylesheet).build(
    ordering_candidates,
  )
  let rng = Lcg::new(0x9e37_79b9_7f4a_7c15)
  for _ in 0..<20 {
    let permuted = shuffle(ordering_candidates, rng)
    let output = @tailwindcss.compile(ordering_stylesheet).build(permuted)
    assert_eq(output, reference)
  }
}

///|
async test "incremental builds match a fresh build of every candidate" {
  let rng = Lcg::new(0x2545_f491_4f6c_dd1d)
  let compiler = @tailwindcss.compile(ordering_stylesheet)
  let seen : Array[String] = []
  let mut latest = ""
  // Feed candidates in small random batches; the accumulating compiler must
  // always agree with a fresh compiler given the same candidate set.
  let pool = shuffle(ordering_candidates, rng)
  let mut index = 0
  while index < pool.length() {
    let batch_size = rng.below(3) + 1
    let batch : Array[String] = []
    for _ in 0..<batch_size {
      if index < pool.length() {
        batch.push(pool[index])
        seen.push(pool[index])
        index += 1
      }
    }
    latest = compiler.build(batch)
    let fresh = @tailwindcss.compile(ordering_stylesheet).build(seen)
    assert_eq(latest, fresh)
  }
}
