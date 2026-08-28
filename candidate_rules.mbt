///|
/// Whether a candidate may carry a leading `-`.
///
/// Upstream registers the negative form of a utility explicitly — `functionalUtility`
/// only binds `-${classRoot}` when the description sets `supportsNegative`, and
/// `spacingUtility` forwards that flag — so `-gap-4` or `-p-4` are not candidates
/// at all, however well their value would resolve. Derived from every
/// `supportsNegative: true` registration and every `utilities.functional('-…')`
/// in upstream `src/utilities.ts`.
let negative_utilities : @set.Set[String] = @set.Set([
  // inset
  "inset", "inset-x", "inset-y", "inset-s", "inset-e", "inset-bs", "inset-be", "top",
  "right", "bottom", "left",
  // grid placement
  "z", "order", "col", "col-start", "col-end", "row", "row-start", "row-end",
  // margin
  "m", "mx", "my", "ms", "me", "mbs", "mbe", "mt", "mr", "mb", "ml",
  // scroll margin
  "scroll-m", "scroll-mx", "scroll-my", "scroll-ms", "scroll-me", "scroll-mbs",
  "scroll-mbe", "scroll-mt", "scroll-mr", "scroll-mb", "scroll-ml",
  // transforms
  "translate", "translate-x", "translate-y", "translate-z", "scale", "scale-x",
  "scale-y", "scale-z", "rotate", "rotate-x", "rotate-y", "rotate-z", "skew", "skew-x",
  "skew-y",
  // spacing between children
  "space-x", "space-y",
  // typography
  "indent", "tracking", "underline-offset",
  // gradients and masks
  "bg-linear", "bg-conic", "mask-linear", "mask-conic",
  // filters
  "hue-rotate", "backdrop-hue-rotate",
  // misc
  "outline-offset",
])

///|
/// Utilities that sit under a negative-supporting name without inheriting it.
/// `inset-shadow` is not `inset` and `col-span` is not `col`, so a prefix match
/// alone would let `-inset-shadow-sm` and `-col-span-4` through. Upstream
/// registers `-translate-full` itself, which is why it is absent here.
let non_negative_utilities : @set.Set[String] = @set.Set([
  "col-span", "row-span", "inset-ring", "inset-shadow", "inset-shadow-initial",
  "rotate-none", "scale-3d", "scale-none", "space-x-reverse", "space-y-reverse",
  "translate-3d", "translate-none",
  // Only the bare angle forms of the gradient masks negate; their stops do not.
  "mask-linear-from", "mask-linear-to", "mask-conic-from", "mask-conic-to",
])

///|
/// `-inset-x-4` is the `inset-x` utility negated, so the utility name is a
/// `-`-bounded prefix of the base rather than the whole of it. The longest
/// prefix wins, so a utility that shadows a shorter negative one answers first.
fn supports_negative(base : String) -> Bool {
  let boundaries = []
  for index in 0..<base.length() {
    if base[index] == '-' {
      boundaries.push(index)
    }
  }
  boundaries.push(base.length())
  for offset in 0..<boundaries.length() {
    let prefix = base[:boundaries[boundaries.length() - 1 - offset]].to_owned()
    if non_negative_utilities.contains(prefix) {
      return false
    }
    if negative_utilities.contains(prefix) {
      return true
    }
  }
  false
}

///|
/// Utilities upstream registers with `supportsFractions`. Only these read a
/// `1/2` as a fraction; everywhere else a `/` is a modifier, which is why
/// `leading-6/2` is not a candidate.
let fraction_utilities : @set.Set[String] = @set.Set([
  "inset", "inset-x", "inset-y", "inset-s", "inset-e", "inset-bs", "inset-be",
  "top", "right", "bottom", "left", "w", "min-w", "max-w", "h", "min-h", "max-h",
  "inline", "min-inline", "max-inline", "block", "min-block", "max-block", "size",
  // `translate-z` is the one axis without fractions.
  "basis", "translate", "translate-x", "translate-y",
  // Not `supportsFractions` upstream, but they read a `<n>/<m>` as a ratio, and
  // the parser hands it over the same way.
  "aspect", "flex",
])

///|
/// Utilities that sit under a fraction-taking name without taking fractions.
let non_fraction_utilities : @set.Set[String] = @set.Set(["translate-z"])

///|
/// The longest utility name answers, so `translate-z-1/2` is not a fraction
/// even though `translate` takes them.
fn supports_fractions(base : String) -> Bool {
  let boundaries = []
  for index in 0..<base.length() {
    if base[index] == '-' {
      boundaries.push(index)
    }
  }
  for offset in 0..<boundaries.length() {
    let prefix = base[:boundaries[boundaries.length() - 1 - offset]].to_owned()
    if non_fraction_utilities.contains(prefix) {
      return false
    }
    if fraction_utilities.contains(prefix) {
      return true
    }
  }
  false
}

///|
/// Whether a declaration takes a candidate's `/modifier` as an alpha channel.
/// The modifier gate and `apply_candidate_value` have to agree on this, so both
/// ask here.
fn is_alpha_property(property : String) -> Bool {
  // `scrollbar-color` names two colors at once; its alpha goes on the two
  // custom properties it composes, which are listed below.
  if property == "scrollbar-color" {
    return false
  }
  property == "color" ||
  property.has_suffix("-color") ||
  property == "fill" ||
  property == "stroke" ||
  property == "--tw-gradient-from" ||
  property == "--tw-gradient-via" ||
  property == "--tw-gradient-to" ||
  property == "--tw-scrollbar-thumb" ||
  property == "--tw-scrollbar-track"
}

///|
/// Whether a value survives negation.
///
/// Upstream never offers a utility's static values to its negative form —
/// `staticValues` is consulted only when the candidate is not negative — so
/// `-z-auto` and `-top-auto` are not candidates. Every value the negative form
/// does reach is a number, dimension, percentage or expression, so a value made
/// only of letters and hyphens is a keyword that arrived from a static branch.
fn is_negatable_value(value : String) -> Bool {
  for index in 0..<value.length() {
    let character = value[index]
    if !((character >= 'a' && character <= 'z') || character == '-') {
      return true
    }
  }
  false
}

