import { readFile, writeFile } from 'node:fs/promises'
import { posix } from 'node:path'
import { compile } from 'tailwindcss'

const request = JSON.parse(await readFile(process.argv[2], 'utf8'))
const files = new Map(
  Object.entries(request.files ?? {}).map(([path, content]) => [
    posix.normalize(path),
    content,
  ]),
)
const compiler = await compile(request.css, {
  base: request.base ?? '',
  async loadStylesheet(id, base) {
    const path = posix.normalize(posix.join(base, id))
    if (!files.has(path)) throw new Error(`Missing oracle stylesheet: ${path}`)
    return {
      content: files.get(path),
      path,
      base: posix.dirname(path) === '.' ? '' : posix.dirname(path),
    }
  },
})
const output = request.builds
  ? JSON.stringify(
      request.builds.map((build) => compiler.build(build.candidates)),
    )
  : compiler.build(request.candidates)
if (process.argv[3]) {
  await writeFile(process.argv[3], output)
} else {
  process.stdout.write(output)
}
