///|
async test "stateful utility families compose generated custom properties" {
  let compiler = @tailwindcss.compile(
    (
      #|@theme {
      #|  --spacing: 0.25rem;
      #|  --color-brand: #123456;
      #|  --blur-soft: 4px;
      #|  --shadow-card: 0 2px 4px #0003;
      #|  --drop-shadow-card: 0 2px 3px #0003;
      #|  --transition-duration-slow: 500ms;
      #|}
      #|@tailwind utilities;
      #|
    ),
  )
  let output = compiler.build([
    "translate-x-4", "rotate-x-45", "scale-110", "touch-pan-x", "snap-mandatory",
    "bg-linear-to-r", "from-brand/50", "shadow-card", "inset-ring-2", "drop-shadow-card",
    "blur-soft", "backdrop-blur-soft", "transition-colors", "duration-slow",
  ])
  assert_true(output.contains("--tw-translate-x: calc(var(--spacing) * 4)"))
  assert_true(output.contains("--tw-rotate-x: rotateX(45deg)"))
  assert_true(output.contains("--tw-scale-z: 110%"))
  assert_true(output.contains("touch-action: var(--tw-pan-x,)"))
  assert_true(output.contains("--tw-scroll-snap-strictness: mandatory"))
  assert_true(output.contains("linear-gradient(var(--tw-gradient-stops))"))
  assert_true(output.contains("--tw-gradient-from: color-mix(in oklab"))
  assert_true(output.contains("box-shadow: var(--tw-inset-shadow)"))
  assert_true(output.contains("--tw-inset-ring-shadow: inset 0 0 0 2px"))
  assert_true(output.contains("--tw-drop-shadow-size: drop-shadow("))
  assert_true(output.contains("backdrop-filter: var(--tw-backdrop-blur,)"))
  assert_true(
    output.contains("transition-duration: var(--transition-duration-slow)"),
  )
  assert_true(output.contains("@property --tw-gradient-from"))
  assert_true(output.contains("@property --tw-ring-shadow"))
  assert_true(output.contains("@property --tw-duration"))
}
