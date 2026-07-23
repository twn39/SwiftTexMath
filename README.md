# SwiftTexMath

Native Swift LaTeX math rendering for Apple platforms: parse → normalize → typeset → draw, with an optional SwiftUI `Math` view.

## Products

| Target | Role |
|---|---|
| **SwiftTexMathCore** | Headless pipeline (`MathParser`, `Typesetter`, `MathRenderer`, CoreGraphics drawing) |
| **SwiftTexMath** | SwiftUI façade (`Math` view, environment keys, layout cache) |

## Quick start

```swift
import SwiftTexMath

Math(#"x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}"#)
    .mathFont(MathFont(name: .latinModern, size: 24))
    .mathTypesettingStyle(.display)
```

Headless:

```swift
import SwiftTexMathCore

let renderer = MathRenderer()
let display = try renderer.layout(latex: #"E = mc^2"#)
// draw with CGContext.draw(_:at:foregroundColor:)
```

## Feature matrix

| Area | Status |
|---|---|
| Fractions `\frac` / `\dfrac` / `\tfrac` / `\binom` | Supported |
| Infix fractions `\over` / `\atop` / `\choose` / `\brack` / `\brace` | Supported |
| Radicals `\sqrt`, `\sqrt[n]` | Supported (MATH `v_variants`) |
| `\left` … `\right` stretchy delimiters | Supported (variants + `v_assembly`) |
| Scripts `^` `_`, large ops + `\limits` | Supported |
| Accents (`\hat`, `\vec`, …) | Supported (accent attachment points) |
| Spacing `\,` `\;` `\!` `\quad` + `\kern`/`\hspace`/`\mkern` | Supported |
| Styles `\displaystyle` / `\textstyle` / … | Supported |
| Font faces `\mathrm` `\mathbf` `\mathit` `\text` `\mathsf` `\mathtt` `\boldsymbol` | Supported |
| Matrices / `cases` / `pmatrix` / `array{c\|cr}` / starred `pmatrix*` | Supported |
| `aligned` / `alignedat` / `split` / `gather` / `gathered` / `eqnarray` | Supported |
| Italic correction on superscripts | Supported |
| `\middle`, `\big`/`\Big`/`\bigg`/`\Bigg` (+ l/r/m) | Supported |
| `\color` / `\textcolor` (named + `#hex`) | Supported |
| `\mathchoice` | Supported |
| `\mathcal` / `\mathscr` / `\mathfrak` / `\mathbb` | Supported |
| Box family `\phantom`/`\smash`/`\llap`/`\cancel`/`\sout`/… | Supported |
| Stack `\overset`/`\underset`/`\stackrel` + stretchy arrows/braces | Supported |
| `\substack`, `\not=` family | Supported |
| Auto line-breaking via `maxWidth` | Supported (relations/binops/spaces; no mid-word) |
| Bundled MATH fonts (LM, XITS, Asana, …) | 12 fonts |

## Architecture

```
LaTeX → MathParser → MathList (atoms)
                  → MathNormalizer
                  → Typesetter → DisplayList
                  → CGContext / SwiftUI Canvas
```

Bundled fonts: Latin Modern Math plus Asana, Euler, Fira, Garamond, Kp Math, Lete Sans, Libertinus, Noto Sans, Termes, and XITS (`mathFonts.bundle`) with OpenType MATH constants, italic corrections, accent attachments, and glyph variants/assemblies.

## Develop

```bash
swift test
```

Rebuild the codegraph vault after structural edits:

```bash
codegraph build . --exclude third_party --exclude .build
```
