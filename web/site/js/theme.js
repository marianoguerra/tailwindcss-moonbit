// Theme switching, ported from margaui's editor/shell.js.
//
// margaui's themes are plain sheets of custom properties (`:root,
// [data-theme="x"] { --color-*: … }`), so they are fetched and adopted at
// runtime rather than compiled: switching a theme costs one small fetch and no
// recompile. The `@theme` registration that makes `bg-primary` resolve at all
// lives in base/theme-colors.css, which *is* part of the compiled bundle.

/**
 * Make a theme sheet apply inside a shadow root as well as the page, by adding
 * `:root, :host` to its first selector. Copied from margaui.
 */
export function adoptableThemeCss(css) {
  return css.replace(/^([^{]*)\{/, ':root, :host, $1{')
}

/**
 * Populate a <select> with the theme list and keep an adopted stylesheet in sync
 * with it.
 *
 * The returned `sheet` is adopted by the document here; a caller that also
 * renders in a shadow root should apply `css` there in its own ordered <style>
 * (see main.js — adopted sheets lose to a shadow tree's own stylesheets, so the
 * preview cannot use this sheet directly).
 */
export async function createThemeSwitcher({
  selectEl,
  themesJsonUrl = 'assets/themes.json',
  themesBaseUrl = 'assets/themes',
  initial = 'light',
  onChange,
}) {
  const names = await fetch(themesJsonUrl).then((response) => response.json())
  const start = names.includes(initial) ? initial : names[0]
  for (const name of names) {
    const option = document.createElement('option')
    option.value = name
    option.textContent = name
    option.selected = name === start
    selectEl.appendChild(option)
  }

  const load = (name) => fetch(`${themesBaseUrl}/${name}.css`).then((response) => response.text())

  const sheet = new CSSStyleSheet()
  let current = start
  let css = await load(start)
  sheet.replaceSync(adoptableThemeCss(css))
  document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet]
  document.body.dataset.theme = start

  selectEl.addEventListener('change', async () => {
    current = selectEl.value
    css = await load(current)
    sheet.replaceSync(adoptableThemeCss(css))
    document.body.dataset.theme = current
    onChange?.(current, css)
  })

  return {
    sheet,
    names,
    get current() {
      return current
    },
    get css() {
      return css
    },
  }
}
