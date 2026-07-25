# tw-mb — an index of everything you can do in this project.
#
#   just            list every recipe, grouped
#   just <recipe>   run one
#
# Conventions:
#   - `moon` drives the MoonBit build; `node` drives the oracle/benchmark tooling.
#   - Backends are `native` (primary), `wasm-gc`, `wasm`, `js`.
#   - Recipes named *-all cover every backend.
#
# Each recipe's one-line summary is what `just --list` prints; longer notes sit
# above it, separated by a blank line so they stay out of the index.

# `moon.work` makes this repo a workspace of two modules — the compiler and the
# showcase site under web/ — so build artifacts are namespaced by module:
#
#   _build/<backend>/release/build/<module>/<package>/…
#
# These module names keep that layout in one place instead of spelling it out in
# every recipe that copies an artifact.
lib := "marianoguerra/tailwindcss"
web := "marianoguerra/tailwindcss-web"

# List every recipe. Runs when you type a bare `just`.
default:
    @just --list --unsorted

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

# A fresh machine has no registry index and deps will not resolve without it,
# so CI runs this in every job. Do NOT use a bare `moon install`: it is
# deprecated and fails to resolve moonbitlang/x and moonbitlang/async.

# Populate the MoonBit registry index (needed on any fresh checkout).
[group('setup')]
deps:
    moon update

# Install the pinned tailwindcss 4.3.3 oracle the differential suite compares against.
[group('setup')]
oracle:
    npm install --prefix tools/oracle

# Everything a fresh checkout needs before `just gate`.
[group('setup')]
setup: deps oracle

# ---------------------------------------------------------------------------
# Develop
# ---------------------------------------------------------------------------

# Format all MoonBit sources in place.
[group('develop')]
fmt:
    moon fmt

# Fail if anything is unformatted, without touching sources.
[group('develop')]
fmt-check:
    moon fmt --check

# This also type-checks the ```mbt blocks in README.mbt.md, so a stale example
# in the docs breaks the build. Note it only *checks* them — the assertions
# inside those blocks are never executed.

# Type-check every backend — the main signal while editing.
[group('develop')]
check:
    moon check --target all --warn-list +unnecessary_annotation

# Type-check one backend: native | wasm-gc | wasm | js
[group('develop')]
check-target target:
    moon check --target {{target}}

# Regenerate the .mbti public-interface files; run after changing anything `pub`.
[group('develop')]
info:
    moon info

# Remove _build.
[group('develop')]
clean:
    moon clean

# ---------------------------------------------------------------------------
# Test
# ---------------------------------------------------------------------------

# MoonBit unit tests.
[group('test')]
test:
    moon test

# Compiles every tools/diff/cases.json case with both this compiler and the
# pinned oracle and compares them. Run `just oracle` once first.

# Differential suite against real tailwindcss (85 cases).
[group('test')]
diff:
    node tools/diff/compare.mjs

# Ordered so the cheapest check fails first. This is what the release workflow
# enforces, plus the differential suite.

# The full correctness gate: fmt-check, check, test, diff, web-smoke.
[group('test')]
gate: fmt-check check test diff web-smoke

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

# Build the native CLI to _build/native/release/build/{{lib}}/cmd/tailwindcss/tailwindcss.exe
[group('build')]
build-cli:
    moon build --release --target native cmd/tailwindcss

# Build the ffi package for one backend: js | wasm-gc | wasm
[group('build')]
build-ffi target:
    moon build --release --target {{target}} ffi

# Mirrors exactly what the release workflow builds, so run it before tagging.

# Build every release artifact: the CLI plus all three ffi backends.
[group('build')]
build-all: build-cli
    moon build --release --target js ffi
    moon build --release --target wasm-gc ffi
    moon build --release --target wasm ffi

# Refresh ffi/js/ffi.js from the js build (the file the npm package ships).
[group('build')]
build-npm: (build-ffi "js")
    cp _build/js/release/build/{{lib}}/ffi/ffi.js ffi/js/ffi.js

# ---------------------------------------------------------------------------
# Showcase site (web/)
# ---------------------------------------------------------------------------

# The site is the second module in this workspace, so `just check` and
# `just test` already cover its MoonBit code. What it needs on top is the
# browser artifact — the wasm-gc build linked with `use-js-builtin-string`, so
# exported functions take and return real JS strings — plus a js build for
# browsers without JS String Builtins. Both are gitignored and rebuilt by CI.

# Build the wasm-gc compiler module the site loads.
[group('site')]
build-web:
    moon build --release --target wasm-gc web/ffi
    cp _build/wasm-gc/release/build/{{web}}/ffi/ffi.wasm web/site/assets/twffi.wasm

# Build the js fallback for browsers without JS String Builtins.
[group('site')]
build-web-fallback:
    moon build --release --target js web/ffi
    cp _build/js/release/build/{{web}}/ffi/ffi.js web/site/assets/twffi.js

# Both browser artifacts.
[group('site')]
build-site: build-web build-web-fallback

# Regenerating needs a margaui checkout (MARGAUI_DIR, default
# /home/mariano/src/margaui); building and deploying the site never does,
# because the output is committed. Pass --with-benchmarks after a
# `just bench-warm` to refresh the snapshot the Benchmarks panel shows.

# Regenerate the committed margaui assets under web/site/assets.
[group('site')]
web-assets *args:
    node tools/gen-web-assets.mjs {{args}}

# Fail if the committed assets differ from what margaui would produce now.
[group('site')]
web-assets-check:
    node tools/gen-web-assets.mjs --check

# Runs the browser's exact instantiation path (compile options, host imports,
# handle lifecycle) under node, so a broken boundary fails here first.

# Smoke-test both browser artifacts outside a browser.
[group('site')]
web-smoke: build-site
    node tools/web-smoke.mjs

# Serve the site at http://localhost:PORT.
[group('site')]
web-serve port="8080": build-site
    python3 -m http.server --directory web/site {{port}}

# What a visitor downloads, next to what npm consumers download.
[group('site')]
web-size: build-site
    #!/usr/bin/env bash
    set -euo pipefail
    row() { printf '%-34s %10s %10s\n' "$1" "$(stat -c%s "$2")" "$(gzip -9c "$2" | wc -c)"; }
    printf '%-34s %10s %10s\n' artifact raw gzip
    row 'site  twffi.wasm (wasm-gc)' web/site/assets/twffi.wasm
    row 'site  twffi.js (fallback)' web/site/assets/twffi.js
    row 'site  margaui-bundle.json' web/site/assets/margaui-bundle.json
    row 'site  shell.css' web/site/assets/shell.css
    row 'site  examples.json' web/site/assets/examples.json
    row 'site  vendored codemirror' web/site/vendor/codemirror/codemirror.js
    row 'npm   ffi/js/ffi.js' ffi/js/ffi.js

# The committed bundle was built out of band; this makes it reproducible.

# Rebuild the vendored CodeMirror bundle from vendor/codemirror/entry.mjs.
[group('site')]
web-codemirror:
    #!/usr/bin/env bash
    set -euo pipefail
    cd web/site/vendor/codemirror
    npm install --no-save codemirror @codemirror/view @codemirror/state \
        @codemirror/lang-css @codemirror/lang-html @codemirror/lang-javascript \
        @codemirror/theme-one-dark @replit/codemirror-vim esbuild
    npx esbuild entry.mjs --bundle --minify --format=esm --outfile=codemirror.js

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

# Candidate discovery is the caller's job — this compiler never scans your
# templates. CANDIDATES is a newline-separated class-name file.
#   just run input.css candidates.txt

# Compile a stylesheet with the native CLI.
[group('run')]
run input candidates="":
    moon run --release --target native cmd/tailwindcss -- \
        -i {{input}} {{ if candidates == "" { "" } else { "-c " + candidates } }}

# Show full CLI help, including the `bundle` and `--batch` sub-modes.
[group('run')]
cli-help:
    moon run --release --target native cmd/tailwindcss -- --help

# Produces the JSON path->content map that the ffi `imports` field and the
# benchmark fixtures both consume.

# Resolve an entry's whole @import graph from disk into a JSON bundle.
[group('run')]
bundle input output="":
    moon run --release --target native cmd/tailwindcss -- \
        bundle -i {{input}} {{ if output == "" { "" } else { "-o " + output } }}

# Workloads: empty one few many a-lot stress variants margaui.
# This is the building block for `just emit-diff`.

# Emit the CSS for one benchmark workload.
[group('run')]
emit workload target="native":
    @moon run --release --target {{target}} benchmarks/bench -- \
        --emit --reqfile benchmarks/workloads/{{workload}}/request.json

# ---------------------------------------------------------------------------
# Benchmark
# ---------------------------------------------------------------------------

# Full suite: every workload x every target, warm + cold. Slow (~30 min).
[group('bench')]
bench:
    node benchmarks/run.mjs

# The shape used for optimization A/B work; see benchmarks/OPTIMIZATIONS.md
# for the protocol (measure back-to-back, never against a stale baseline).

# Warm-only run over the heavy tiers and all three tw-mb backends.
[group('bench')]
bench-warm:
    node benchmarks/run.mjs --workload a-lot,stress,margaui \
        --targets native,wasm-gc,js --trials 3 --no-cold

# Native-only smoke run, for a quick read while iterating.
[group('bench')]
bench-quick:
    node benchmarks/run.mjs --workload a-lot,stress,margaui \
        --targets native --trials 3 --no-cold

# Run an arbitrary slice: just bench-run "--workload variants --targets native"
[group('bench')]
bench-run args:
    node benchmarks/run.mjs {{args}}

# Deterministic, so re-running leaves the tree clean. Pass --with-margaui
# (needs MARGAUI_DIR, default /home/mariano/src/margaui) to rebuild that tier.

# Regenerate the committed workload fixtures.
[group('bench')]
bench-generate *args:
    node benchmarks/generate.mjs {{args}}

# ---------------------------------------------------------------------------
# Verify a change
# ---------------------------------------------------------------------------

# A passing gate does NOT prove output identity — it proves the cases still
# pass. This compares emitted CSS byte for byte between HEAD and the working
# tree, which is what kept the opt 15-29 speedups honest. Needs a tree that
# `git stash` can round-trip.

# Prove a refactor changed no output, on every workload.
[group('verify')]
emit-diff:
    #!/usr/bin/env bash
    set -euo pipefail
    out=$(mktemp -d)
    trap 'rm -rf "$out"' EXIT
    workloads="empty one few many a-lot stress variants margaui"
    # Inline rather than recursing into `just emit`: the stash below takes
    # untracked files too, so an uncommitted justfile is gone by then.
    emit() {
        moon run --release --target native benchmarks/bench -- \
            --emit --reqfile "benchmarks/workloads/$1/request.json"
    }
    echo "==> emitting working tree"
    for w in $workloads; do emit "$w" > "$out/$w.after"; done
    echo "==> stashing, emitting HEAD"
    stashed=0
    if git stash push -q -u -m just-emit-diff; then stashed=1; fi
    # Restore the tree even if an emit fails partway.
    trap 'rm -rf "$out"; [ "$stashed" = 1 ] && git stash pop -q' EXIT
    for w in $workloads; do emit "$w" > "$out/$w.before"; done
    if [ "$stashed" = 1 ]; then git stash pop -q; stashed=0; fi
    trap 'rm -rf "$out"' EXIT
    echo "==> comparing"
    status=0
    for w in $workloads; do
        if cmp -s "$out/$w.before" "$out/$w.after"; then
            echo "  $w IDENTICAL"
        else
            echo "  $w DIFFERS"
            status=1
        fi
    done
    exit $status

# ---------------------------------------------------------------------------
# Profile
# ---------------------------------------------------------------------------

# moon-pprof lives in ~/.cargo/bin. Linux perf is unavailable here
# (perf_event_paranoid=4, no sudo), so CPU profiling goes through the wasm-gc
# guest profiler, which cannot forward argv — the workload has to be embedded
# in a throwaway harness. Always profile a REPRESENTATIVE workload: a
# dispatch-only synthetic mis-ranked the bottleneck and sent optimizations 6
# and 7 chasing a cost that is minor on real input.

# Native allocation profile; use a SMALL workload (the hook SIGSEGVs on big ones).
[group('profile')]
profile-alloc workload="many":
    moon build --release --target native benchmarks/bench
    moon-pprof memprofile-native \
        _build/native/release/build/{{lib}}/benchmarks/bench/bench.exe \
        -- --emit --reqfile benchmarks/workloads/{{workload}}/request.json

# Print top self-time from a captured profile.
[group('profile')]
profile-summary pb:
    moon-pprof summary {{pb}}

# Caller attribution is what found the single largest win in this project
# (opt 15): roll up the frame *below* each hot leaf instead of reading
# self-time alone.

# Convert a profile to folded stacks for caller attribution.
[group('profile')]
profile-folded pb out:
    moon-pprof pprof2folded {{pb}} {{out}}

# ---------------------------------------------------------------------------
# Release
# ---------------------------------------------------------------------------

# Pushing a v* tag drives .github/workflows/release.yml, which publishes to
# mooncakes, to npm (OIDC trusted publishing, no token), and to a GitHub
# Release carrying the native/wasm/js artifacts. Remote tags cannot be
# re-pointed, so a bad tag costs a version number — always run release-check.

# Show the version from both files and fail if they disagree.
[group('release')]
version:
    #!/usr/bin/env bash
    set -euo pipefail
    mod=$(grep -oP '^version = "\K[^"]+' moon.mod)
    pkg=$(node -p "require('./ffi/js/package.json').version")
    web=$(grep -oP '^const COMPILER_VERSION : String = "\K[^"]+' web/ffi/lib.mbt)
    echo "moon.mod            $mod"
    echo "ffi/js/package.json $pkg"
    echo "web/ffi/lib.mbt     $web"
    if [ "$mod" != "$pkg" ] || [ "$mod" != "$web" ]; then echo "MISMATCH"; exit 1; fi

# The version lives in three files that must stay in sync: the module manifest,
# the npm package, and the constant the site reports in its footer.

# Bump the version in moon.mod, ffi/js/package.json and web/ffi/lib.mbt.
[group('release')]
version-bump version:
    sed -i 's/^version = ".*"/version = "{{version}}"/' moon.mod
    sed -i '0,/"version": ".*"/s//"version": "{{version}}"/' ffi/js/package.json
    sed -i 's/^const COMPILER_VERSION : String = ".*"/const COMPILER_VERSION : String = "{{version}}"/' web/ffi/lib.mbt
    @just version

# Everything CI will run, plus every artifact CI will build.
[group('release')]
release-check: gate build-all

# Tag and push, triggering the release workflow. Run release-check first.
[group('release')]
release-tag version:
    git tag -a v{{version}} -m "v{{version}}"
    git push origin v{{version}}

# List recent release workflow runs.
[group('release')]
release-status:
    gh run list --workflow=release.yml --limit 3
