// Source of the vendored codemirror.js bundle.
//
// The committed bundle came from margaui, where it was built out of band; this
// file records the entry point that produces it so it can be rebuilt rather than
// trusted blindly:
//
//   npm i codemirror @codemirror/{view,state,lang-css,lang-html,lang-javascript,theme-one-dark} \
//         @replit/codemirror-vim
//   npx esbuild entry.mjs --bundle --minify --format=esm --outfile=codemirror.js
//
// `just web-codemirror` runs that. The export names are what web/site/js/code-editor.js
// destructures, and match the existing bundle's export list exactly:
//   { vim, javascript, html, darkTheme, css, basicSetup, Vim, EditorView, EditorState }
export { basicSetup } from 'codemirror'
export { EditorView } from '@codemirror/view'
export { EditorState } from '@codemirror/state'
export { css } from '@codemirror/lang-css'
export { html } from '@codemirror/lang-html'
export { javascript } from '@codemirror/lang-javascript'
export { oneDark as darkTheme } from '@codemirror/theme-one-dark'
export { vim, Vim } from '@replit/codemirror-vim'
