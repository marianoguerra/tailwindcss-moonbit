name = "marianoguerra/tailwindcss"

version = "0.1.3"

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
  exclude: [ "tools", "examples", "migration-plan.md", "package.json" ],
)
