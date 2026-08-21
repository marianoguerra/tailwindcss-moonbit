name = "marianoguerra/tailwindcss"

version = "0.3.0"

readme = "README.mbt.md"

license = "MIT"

repository = "https://github.com/marianoguerra/tailwindcss-moonbit"

keywords = [ "css", "tailwindcss", "compiler" ]

description = "A MoonBit implementation of the Tailwind CSS v4 compiler"

import {
  "moonbitlang/x@0.5.1",
  "moonbitlang/async@0.21.0",
}

options(
  exclude: [
    "tools",
    "examples",
    "benchmarks",
    "web",
    "package.json",
    "moon.work",
  ],
)
