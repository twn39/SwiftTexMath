# SwiftTexMath

Native Swift LaTeX math rendering for Apple platforms: **parse → normalize → typeset → draw**, with an optional SwiftUI `Math` view and UIKit/AppKit `MathLabel`.

**Platforms:** macOS 14+, iOS 17+, tvOS 17+, watchOS 10+, visionOS 1+ · **Swift tools:** 6.2+

## Installation

Add the package in Xcode (**File → Add Package Dependencies…**) or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/twn39/SwiftTexMath.git", branch: "main"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "SwiftTexMath", package: "SwiftTexMath"),
            // Or Core only:
            // .product(name: "SwiftTexMathCore", package: "SwiftTexMath"),
        ]
    ),
]
```

## Products

| Target | Role |
|---|---|
| **SwiftTexMathCore** | Headless pipeline (`MathParser`, `Typesetter`, `MathRenderer`, `MathImage`, CoreGraphics drawing) |
| **SwiftTexMath** | UI façade (`Math`, `MathLabel`, `HostedMathLabel`, environment keys, layout cache) |

Dependency direction is one-way: **SwiftTexMath → SwiftTexMathCore**.

## Quick start

### SwiftUI

```swift
import SwiftTexMath

Math(#"x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}"#)
    .mathFont(MathFont(name: .latinModern, size: 24))
    .mathTypesettingStyle(.display)
    .mathRenderingMode(.monochrome)
```

Useful environment modifiers: `.mathFont(_:)`, `.mathTypesettingStyle(_:)`, `.mathRenderingMode(_:)`, `.mathFonts(_:)`, `.mathTextFallbackFontName(_:)`.

### UIKit / AppKit

```swift
import SwiftTexMath

let label = MathLabel()
label.latex = #"E = mc^2"#
label.mathFont = MathFont(name: .latinModern, size: 24)
label.preferredMaxLayoutWidth = 280
```

Or embed via SwiftUI: `HostedMathLabel(latex: …)`.

### Headless layout + draw

```swift
import SwiftTexMathCore

let renderer = MathRenderer()
let display = try renderer.layout(latex: #"E = mc^2"#)
// CGContext.draw(display, at:origin, foregroundColor:fonts:)
```

### Raster export / snapshots

```swift
import SwiftTexMathCore

let result = try MathImage.render(latex: #"a^2 + b^2 = c^2"#)
let cgImage = result.image          // pixel bitmap
let pointSize = result.size         // logical size in points
```

### Vector PDF export

```swift
import SwiftTexMathCore

let pdf = try MathPDF.render(latex: #"E = mc^2"#)
// Write `pdf` to disk or share; media box is expression size + padding.
```

### Vector SVG export

```swift
import SwiftTexMathCore

let svg = try MathSVG.render(latex: #"E = mc^2"#)
// svg.svg is a full document string; svg.data is UTF-8.
// Glyphs are outline paths (portable; no font embedding).
try svg.data.write(to: URL(fileURLWithPath: "/tmp/math.svg"))
```

## Feature matrix

| Area | Status |
|---|---|
| Fractions `\frac` / `\dfrac` / `\tfrac` / `\cfrac[l\|c\|r]` / `\binom` / `\genfrac` | Supported |
| Infix fractions `\over` / `\atop` / `\choose` / `\brack` / `\brace` | Supported |
| Radicals `\sqrt`, `\sqrt[n]` | Supported (MATH `v_variants`) |
| `\left` … `\right` stretchy delimiters | Supported (variants + `v_assembly`) |
| Scripts `^` `_` / prime `'` / large ops + `\limits` / `\nolimits` | Supported |
| Accents (`\hat`, `\vec`, `\widehat`, `\utilde`, `\underaccent`, …) | Supported (MATH attach + h-variants / `h_assembly`) |
| Spacing `\,` `\:` `\;` `\!` `\quad` + `\kern` / `\hspace` / `\mkern` | Supported |
| Styles `\displaystyle` / `\textstyle` / … | Supported |
| Font faces `\mathrm` `\mathbf` `\mathit` `\text` `\mathsf`/`\textsf` `\mathtt`/`\texttt` `\boldsymbol` + `\bf`/`\rm`/`\mit` | Supported |
| Matrices / `cases` / `pmatrix` / `array{c\|cr}` / starred `pmatrix*` | Supported |
| `aligned` / `alignedat` / `split` / `gather` / `gathered` / `eqnarray` / `align` | Supported |
| `array` `@{…}` column inserts + `\hline` / vlines | Supported |
| Italic correction on superscripts | Supported |
| `\middle`, `\big`/`\Big`/`\bigg`/`\Bigg` (+ l/r/m) | Supported |
| `\color` / `\textcolor` / `\colorbox` (named + `#hex`) | Supported |
| `\mathchoice` | Supported |
| `\mathcal` / `\mathscr` / `\mathfrak` / `\mathbb` | Supported |
| Box family `\phantom`/`\smash`/`\llap`/`\cancel`/`\sout`/`\boxed`/… | Supported |
| Stack `\overset`/`\underset`/`\stackrel` + stretchy arrows/braces | Supported |
| `\substack`, `\not=` family | Supported |
| Macros `\operatorname`/`\operatorname*`, `\pmod`/`\pod`/`\bmod`, `\bra`/`\ket`/`\braket`, `\mathbin`…`\mathpunct`, `\tag` | Supported |
| Multi-integrals `\iint`…`\oiint`/`\oiiint`/`\fint`/… | Supported |
| AMS aliases (`\lt`/`\gt`/`\therefore`/`\impliedby`/`\dotsc`/…) | Supported |
| Custom symbols (`AtomFactory.addLatexSymbol`) | Supported |
| `MathList.latexString` / `LatexSerializer` | Supported (best-effort; see limitations) |
| Auto line-breaking via `maxWidth` | Supported (rel/binop/space; mid-word as last resort) |
| Bundled MATH fonts (LM, XITS, Asana, …) | 12 fonts |
| Vector PDF export (`MathPDF`) | Supported |
| Vector SVG export (`MathSVG`) | Supported (glyph outlines) |
| User macros `\newcommand` / `\def` (0–9 args) | Supported (per-parse session) |
| `\intertext` in align/gather-style envs | Supported (full-width upright row) |

Delimiters `$…$` / `$$…$$` / `\(...\)` / `\[…\]` are stripped at parse time and inject an implied style atom when present.

### Known limitations

See **[docs/KNOWN_LIMITATIONS.md](docs/KNOWN_LIMITATIONS.md)** for wrap/`\tag`/serializer caveats, and **[docs/layout-geometry-status.md](docs/layout-geometry-status.md)** for numeric geometry goldens. Payload changes: **[docs/PAYLOAD_CHECKLIST.md](docs/PAYLOAD_CHECKLIST.md)**.

### Accent commands

| Command | Placement | Notes |
|---|---|---|
| `\hat` `\tilde` `\bar` `\vec` `\dot` `\ddot` `\check` `\breve` `\acute` `\grave` | Above | MATH top accent attachment |
| `\widehat` `\widetilde` | Above, stretchy | Horizontal variants; assembly when present |
| `\utilde` `\underbar` | Below | Prefers `*belowcmb` glyphs |
| `\underrightarrow` `\underleftarrow` | Below, stretchy | Horizontal variants / `h_assembly` |
| `\accent{mark}{base}` `\overaccent{mark}{base}` | Above | Free-form mark (script size) or bare accent name |
| `\underaccent{mark}{base}` | Below | Same; e.g. `\underaccent{\tilde}{x}` or `\underaccent{\ast}{x}` |

Prefer `\utilde{x}` for a dedicated under-tilde. `\underaccent{\tilde}{x}` is accepted (bare accent name as mark). Avoid nested bases like `\underaccent{\tilde{y}}{x}`.

## Architecture

```
LaTeX → MathParser → MathList (atoms)
                  → MathNormalizer
                  → Typesetter → DisplayList
                  → CGContext / MathImage / SwiftUI Canvas / MathLabel
```

### Package layout (Core)

| Folder | Responsibility |
|---|---|
| `Parse/` | Recursive-descent parser + command families (`FractionCommands`, `DelimiterCommands`, `MacroCommands+*`, …) |
| `Syntax/` | `MathAtom` / `MathList` / `AtomFactory` / serializers |
| `Normalize/` | Pre-layout AST cleanup (number fusion, Bin→Ord, bare boundaries) |
| `Layout/` | Appendix-G typesetting (`Typesetter`, `WrapLayout`, `TableLayout`, …) |
| `Display/` | `DisplayList` + CoreGraphics drawing |
| `Font/` | `MathFont`, `FontMetrics`, `FontRegistry` / `FontProviding` |

Parser helpers live in extensions: `MathParser+Arguments`, `+Tables`, `+Scripts`, `+Commands`. Macro sugar is split by family (`MacroCommands+OperatorName`, `+BraKet`, `+ModTag`) behind a thin `MacroCommands` router. Keep `CommandHandlers` and `Typesetter` as dispatchers—not feature dumps.

### Bundled fonts

Latin Modern Math plus Asana, Euler, Fira, Garamond, Kp Math, Lete Sans, Libertinus, Noto Sans, Termes, and XITS (`mathFonts.bundle`), with OpenType MATH constants, italic corrections, accent attachments, and glyph variants/assemblies.

### Architecture invariants

- **Normalize before Layout.** `MathNormalizer` owns TeX sugar cleanup (e.g. dropping bare `.boundary` atoms). Typesetter may still skip boundaries as defense-in-depth; new semantic lowering belongs in Normalize / Parse—not ad-hoc layout branches.
- **Payload growth discipline.** Prefer extending `MathAtom.Payload` only when a construct needs a distinct layout shape. Register new commands in family modules or `*Layout.swift` helpers.
- **Font injection & SwiftUI cache.** `MathRenderer`, `MathImage`, and `.mathFonts(...)` accept any `FontProviding`. `DisplayProvider` caches layout **only** when the provider is identity-equal to `FontRegistry.shared`. Custom providers always recompute.

### Errors

Parse failures throw `ParseError` with a stable `Code` (`mismatchedBraces`, `invalidEnvironment`, `missingEnd`, `invalidLimits`, …). UI surfaces (`Math`, `MathLabel`) can show inline error text instead of crashing.

## Develop

```bash
swift test
```

Headless demo (print metrics; optional PNG path):

```bash
swift run SwiftTexMathDemo
swift run SwiftTexMathDemo 'E=mc^2' /tmp/math.png
```

Core tests include goldens (`Tests/SwiftTexMathCoreTests/Goldens`), layout fingerprints, architecture hardening (table/delimiter failure modes), and a tex2math corpus. UI tests stay thin and exercise the SwiftTexMath façade.

Project scan settings live in `.codegraphrc` (`Sources` + `Tests`). Rebuild the knowledge graph after structural edits:

```bash
codegraph build .
# or: codegraph build . -e .build -e third_party
```

Agent guidelines: see [`AGENTS.md`](AGENTS.md) and [`.codegraph/README.md`](.codegraph/README.md).
