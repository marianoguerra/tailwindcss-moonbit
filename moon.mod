name = "marianoguerra/tailwindcss"

version = "0.2.0"

readme = "README.mbt.md"

license = "MIT"

repository = "https://github.com/marianoguerra/tailwindcss-moonbit"

keywords = [ "css", "tailwindcss", "compiler" ]

description = "A MoonBit implementation of the Tailwind CSS v4 compiler"

import {
  "moonbitlang/x@0.4.46",
  "moonbitlang/async@0.20.2",
}

options(
  exclude: [
    "tools",
    "examples",
    "benchmarks",
    "migration-plan.md",
    "package.json",
  ],
)
