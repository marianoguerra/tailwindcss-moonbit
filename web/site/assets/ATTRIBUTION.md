# Attribution

The stylesheets and example markup under this directory are generated from
[margaui](https://github.com/marianoguerra/margaui) (`de7b235`, MIT), a Tailwind CSS v4
component library by Mariano Guerra, itself modelled on
[daisyUI](https://daisyui.com/) (MIT) and built on
[Tailwind CSS](https://tailwindcss.com/) (MIT).

`margaui-bundle.json` embeds the flattened Tailwind CSS entry stylesheet from the
upstream `tailwindcss` package, and the compiled `shell.css` derives from both.

Regenerate with `just web-assets`; see `tools/gen-web-assets.mjs`.

The editor also vendors [CodeMirror 6](https://codemirror.net/) (MIT) and
[@replit/codemirror-vim](https://github.com/replit/codemirror-vim) (MIT) under
`web/site/vendor/codemirror/`, which carries its own LICENSE.
