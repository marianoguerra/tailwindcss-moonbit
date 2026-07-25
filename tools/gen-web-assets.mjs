// Showcase-site asset generator.
//
// Writes the committed files under web/site/assets/ that the editor loads: the
// flattened margaui CSS graph, the theme sheets, the example corpus, and the
// precompiled page chrome. Output is DETERMINISTIC (sorted) so re-running leaves
// the tree clean.
//
//   node tools/gen-web-assets.mjs                    # regenerate everything
//   node tools/gen-web-assets.mjs --with-benchmarks  # also refresh benchmarks.json
//   node tools/gen-web-assets.mjs --check            # fail if anything is stale
//
// margaui is an external checkout (default /home/mariano/src/margaui, override
// with MARGAUI_DIR or --margaui-dir) but the OUTPUT is committed, so building or
// deploying the site never needs that checkout.
import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const assetsDir = join(root, 'web/site/assets')
const argv = process.argv.slice(2)
const withBenchmarks = argv.includes('--with-benchmarks')
const checkOnly = argv.includes('--check')
const dirFlag = argv.indexOf('--margaui-dir')
const margauiDir =
  dirFlag === -1 ? (process.env.MARGAUI_DIR ?? '/home/mariano/src/margaui') : argv[dirFlag + 1]

// Components shown first in the picker, in this order. Everything else follows
// alphabetically. Ids that no longer exist upstream are skipped, not an error.
const FEATURED = [
  'button',
  'card',
  'navbar',
  'alert',
  'badge',
  'table',
  'input',
  'select',
  'modal',
  'tab',
  'hero',
  'stat',
  'chat',
  'menu',
]

const changed = []

/** Write `content` unless it is already on disk; returns true when it differed. */
function emit(relative, content) {
  const path = join(assetsDir, relative)
  const previous = existsSync(path) ? readFileSync(path, 'utf8') : null
  if (previous === content) return false
  changed.push(relative)
  if (!checkOnly) {
    mkdirSync(dirname(path), { recursive: true })
    writeFileSync(path, content)
  }
  return true
}

function json(value) {
  return `${JSON.stringify(value, null, 2)}\n`
}

/** "card-body" -> "Card body" */
function humanize(name) {
  const spaced = name.replace(/[-_]+/g, ' ')
  return spaced.charAt(0).toUpperCase() + spaced.slice(1)
}

function nativeCli() {
  const exe = join(
    root,
    '_build/native/release/build/marianoguerra/tailwindcss/cmd/tailwindcss/tailwindcss.exe',
  )
  if (!existsSync(exe)) {
    execFileSync('moon', ['build', '--release', '--target', 'native', 'cmd/tailwindcss'], {
      cwd: root,
      stdio: 'inherit',
    })
  }
  return exe
}

// ---- the margaui bundle -----------------------------------------------------

// Lines dropped from margaui's entry before bundling:
//   - the bare "tailwindcss" specifier, which the filesystem loader cannot
//     resolve (the flattened upstream entry is injected under that key instead)
//   - the themes import, because themes are fetched and adopted at runtime so the
//     theme picker can switch them without recompiling
//   - @source, which scans template files that do not exist in a browser
const TAILWIND_IMPORT = /^.*@import\s+["']tailwindcss["'].*$\n?/m
const THEMES_IMPORT = /^.*@import\s+["']\.\/themes\/theme\.css["'].*$\n?/m
const SOURCE_DIRECTIVE = /^\s*@source\s+[^;]*;\s*$\n?/gm

function buildBundle() {
  const entry = readFileSync(join(margauiDir, 'entry.css'), 'utf8')
  const requestCss = entry.replace(THEMES_IMPORT, '').replace(SOURCE_DIRECTIVE, '')
  // Bundle from a temp copy in margaui's own directory, so the relative
  // "./src/*.css" keys the compiler records stay unchanged.
  const tempEntry = join(margauiDir, '.__web_entry.css')
  writeFileSync(tempEntry, requestCss.replace(TAILWIND_IMPORT, ''))
  let imports
  try {
    imports = JSON.parse(
      execFileSync(nativeCli(), ['bundle', '-i', tempEntry], {
        cwd: root,
        encoding: 'utf8',
        maxBuffer: 256 * 1024 * 1024,
      }),
    )
  } finally {
    rmSync(tempEntry, { force: true })
  }
  // The entry itself comes back under "", which the request carries as `css`.
  delete imports['']

  const shared = join(root, 'benchmarks/workloads/_shared/tailwindcss-bundle.json')
  const oracle = join(root, 'tools/oracle/node_modules/tailwindcss/index.css')
  if (existsSync(shared)) {
    imports.tailwindcss = JSON.parse(readFileSync(shared, 'utf8')).tailwindcss
  } else if (existsSync(oracle)) {
    imports.tailwindcss = readFileSync(oracle, 'utf8')
  } else {
    throw new Error(`no flattened tailwindcss entry found (looked in ${shared} and ${oracle})`)
  }

  const sorted = {}
  for (const key of Object.keys(imports).sort()) sorted[key] = imports[key]
  return {
    source: {
      repo: 'https://github.com/marianoguerra/margaui',
      commit: gitCommit(margauiDir),
      license: 'MIT',
      generatedBy: 'tools/gen-web-assets.mjs',
    },
    css: requestCss,
    from: 'entry.css',
    base: '',
    polyfills: 3,
    imports: sorted,
  }
}

function gitCommit(dir) {
  try {
    return execFileSync('git', ['rev-parse', '--short', 'HEAD'], { cwd: dir, encoding: 'utf8' }).trim()
  } catch {
    return 'unknown'
  }
}

// ---- themes ----------------------------------------------------------------

// theme.css is only an aggregate of light + dark, so it is not a pickable theme.
function buildThemes() {
  const dir = join(margauiDir, 'themes')
  const names = readdirSync(dir)
    .filter((file) => file.endsWith('.css') && file !== 'theme.css')
    .map((file) => file.replace(/\.css$/, ''))
    .sort()
  for (const name of names) {
    emit(`themes/${name}.css`, readFileSync(join(dir, `${name}.css`), 'utf8'))
  }
  emit('themes.json', json(names))
  return names
}

// ---- examples --------------------------------------------------------------

// Upstream ships several variants per component; the editor keeps one, so it
// keeps the most illustrative rather than the plainest — the variant using the
// most distinct classes, which for `button` is the row of colour modifiers
// instead of a bare `<button class="btn">`. Files over SNIPPET_LIMIT bytes are
// skipped so a handful of enormous demos cannot dominate the payload; that keeps
// the committed corpus around 40 KB instead of the full 2.3 MB of 563 snippets.
const SNIPPET_LIMIT = 4096

function classCount(html) {
  const classes = new Set()
  for (const match of html.matchAll(/class\s*=\s*"([^"]*)"/g)) {
    for (const name of match[1].split(/\s+/)) if (name) classes.add(name)
  }
  return classes.size
}

function buildExamples() {
  const componentsPath = join(margauiDir, 'playground/components.json')
  if (!existsSync(componentsPath)) {
    throw new Error(`missing ${componentsPath} — run \`npm run playground\` in margaui first`)
  }
  const components = JSON.parse(readFileSync(componentsPath, 'utf8'))
  const byId = new Map()
  for (const { name, files } of components) {
    if (!files?.length) continue
    const variants = files
      .map((file) => {
        const html = readFileSync(
          join(margauiDir, 'playground/components', name, file),
          'utf8',
        ).trimEnd()
        return { file, html, classes: classCount(html), bytes: Buffer.byteLength(html) }
      })
      .sort(
        (a, b) =>
          Number(a.bytes > SNIPPET_LIMIT) - Number(b.bytes > SNIPPET_LIMIT) ||
          b.classes - a.classes ||
          a.bytes - b.bytes ||
          a.file.localeCompare(b.file),
      )
    const preferred = variants[0]
    byId.set(name, {
      id: name,
      title: humanize(name),
      group: 'components',
      file: `${name}/${preferred.file}`,
      html: preferred.html,
    })
  }
  const examples = []
  for (const id of FEATURED) {
    const example = byId.get(id)
    if (!example) continue
    examples.push({ ...example, group: 'featured' })
    byId.delete(id)
  }
  for (const id of [...byId.keys()].sort()) examples.push(byId.get(id))
  emit('examples.json', json(examples))
  return examples
}

// ---- page chrome -----------------------------------------------------------

// The site styles itself with margaui, but it cannot wait for the compiler to
// load without flashing unstyled content — so compile the chrome up front. This
// goes through the benchmark harness's --emit mode, which takes the same request
// JSON as the browser entry points, so no new tooling is needed.
function buildShellCss(bundle) {
  const listPath = join(root, 'web/site/shell-classes.txt')
  const candidates = readFileSync(listPath, 'utf8')
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line !== '' && !line.startsWith('#'))
  const requestPath = join(root, '_build/web-shell-request.json')
  mkdirSync(dirname(requestPath), { recursive: true })
  writeFileSync(
    requestPath,
    JSON.stringify({
      css: bundle.css,
      imports: bundle.imports,
      base: bundle.base,
      from: bundle.from,
      polyfills: bundle.polyfills,
      candidates,
    }),
  )
  let css
  try {
    css = execFileSync(
      'moon',
      [
        'run',
        '--release',
        '--target',
        'native',
        'benchmarks/bench',
        '--',
        '--emit',
        '--reqfile',
        requestPath,
      ],
      { cwd: root, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 },
    )
  } finally {
    rmSync(requestPath, { force: true })
  }
  emit(
    'shell.css',
    `/* Generated by tools/gen-web-assets.mjs from web/site/shell-classes.txt.\n` +
      `   ${candidates.length} classes of page chrome, compiled ahead of time so the\n` +
      `   site is styled before any JavaScript runs. Do not edit. */\n${css}`,
  )
  return { candidates, css }
}

// ---- benchmark snapshot ----------------------------------------------------

// benchmarks/results/ is gitignored, so the site ships a snapshot of a local run
// for context next to the visitor's own "Run xN" numbers.
function buildBenchmarks() {
  const resultsPath = join(root, 'benchmarks/results/results.json')
  if (!existsSync(resultsPath)) {
    console.warn(`! ${resultsPath} not found; leaving benchmarks.json alone (run \`just bench-warm\`)`)
    return null
  }
  const results = JSON.parse(readFileSync(resultsPath, 'utf8'))
  const workloads = []
  for (const workload of results.workloads ?? []) {
    const row = results.warm?.[workload.id]
    if (!row) continue
    const targets = {}
    for (const name of Object.keys(row).sort()) {
      const median = row[name]?.stats?.median_us
      const min = row[name]?.stats?.min_us
      if (typeof median !== 'number') continue
      targets[name] = { medianUs: round(median), minUs: round(min) }
    }
    workloads.push({
      id: workload.id,
      candidates: workload.candidateCount,
      cssVariant: workload.cssVariant,
      targets,
    })
  }
  emit(
    'benchmarks.json',
    json({
      source: {
        note: 'Warm medians from a local `just bench-warm` run; see benchmarks/README.md for the methodology.',
        timestamp: results.env?.timestamp ?? null,
        cpu: results.env?.cpu ?? null,
        platform: results.env?.platform ?? null,
        commit: results.env?.gitCommit ?? null,
        oracle: results.env?.tailwindcssOracleVersion ?? null,
        trials: results.config?.trials ?? null,
      },
      workloads,
    }),
  )
  return workloads
}

function round(value) {
  return typeof value === 'number' ? Math.round(value * 10) / 10 : null
}

// ---- drive -----------------------------------------------------------------

if (!existsSync(margauiDir)) {
  console.error(`margaui checkout not found at ${margauiDir}`)
  console.error('pass --margaui-dir DIR or set MARGAUI_DIR')
  process.exit(1)
}

const bundle = buildBundle()
emit('margaui-bundle.json', json(bundle))
const themes = buildThemes()
const examples = buildExamples()
const shell = buildShellCss(bundle)
const benchmarks = withBenchmarks ? buildBenchmarks() : null

emit(
  'ATTRIBUTION.md',
  [
    '# Attribution',
    '',
    'The stylesheets and example markup under this directory are generated from',
    `[margaui](${bundle.source.repo}) (\`${bundle.source.commit}\`, MIT), a Tailwind CSS v4`,
    'component library by Mariano Guerra, itself modelled on',
    '[daisyUI](https://daisyui.com/) (MIT) and built on',
    '[Tailwind CSS](https://tailwindcss.com/) (MIT).',
    '',
    '`margaui-bundle.json` embeds the flattened Tailwind CSS entry stylesheet from the',
    'upstream `tailwindcss` package, and the compiled `shell.css` derives from both.',
    '',
    'Regenerate with `just web-assets`; see `tools/gen-web-assets.mjs`.',
    '',
    'The editor also vendors [CodeMirror 6](https://codemirror.net/) (MIT) and',
    '[@replit/codemirror-vim](https://github.com/replit/codemirror-vim) (MIT) under',
    '`web/site/vendor/codemirror/`, which carries its own LICENSE.',
    '',
  ].join('\n'),
)

const summary = [
  `margaui  ${bundle.source.commit}`,
  `bundle   ${Object.keys(bundle.imports).length} imports, ${byteSize(json(bundle))}`,
  `themes   ${themes.length}`,
  `examples ${examples.length} (${examples.filter((e) => e.group === 'featured').length} featured), ${byteSize(json(examples))}`,
  `shell    ${shell.candidates.length} classes -> ${byteSize(shell.css)}`,
  benchmarks ? `bench    ${benchmarks.length} workloads` : 'bench    (unchanged)',
]
for (const line of summary) console.log(`  ${line}`)

function byteSize(text) {
  const bytes = Buffer.byteLength(text)
  return bytes >= 1024 * 1024
    ? `${(bytes / 1024 / 1024).toFixed(2)} MB`
    : `${(bytes / 1024).toFixed(1)} KB`
}

if (checkOnly) {
  if (changed.length === 0) {
    console.log('\nassets are up to date')
    process.exit(0)
  }
  console.error(`\n${changed.length} asset(s) would change:`)
  for (const name of changed) console.error(`  ${name}`)
  process.exit(1)
}
console.log(changed.length === 0 ? '\nno changes' : `\nwrote ${changed.length} file(s)`)
