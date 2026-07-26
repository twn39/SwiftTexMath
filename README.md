# SwiftTexMath

Native, high-performance LaTeX math rendering engine for Apple platforms written in Swift.

[![CI](https://img.shields.io/github/actions/workflow/status/twn39/SwiftTexMath/ci.yml?branch=main&label=CI&style=flat-square&logo=github-actions)](https://github.com/twn39/SwiftTexMath/actions/workflows/ci.yml)
[![Swift 6.1+](https://img.shields.io/badge/Swift-6.1%2B-orange.svg?style=flat-square&logo=swift)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%2014+%20%7C%20iOS%2017+%20%7C%20tvOS%2017+%20%7C%20watchOS%2010+%20%7C%20visionOS%201+-blue.svg?style=flat-square&logo=apple)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)]()
[![Zero Dependencies](https://img.shields.io/badge/Dependencies-Zero-brightgreen.svg?style=flat-square)]()

**SwiftTexMath** executes a pure Swift TeX layout pipeline (**parse → normalize → typeset → draw**) with zero external dependencies. It provides full-featured SwiftUI `Math` views, UIKit/AppKit `MathLabel` components, CoreGraphics rendering, and vector (PDF/SVG) and bitmap (PNG) export capabilities.

---

## ⚡️ Key Features

- **Pure Swift & Swift 6 Ready**: Implements the TeX Appendix-G typesetting specification with strict concurrency support.
- **First-Class UI Components**: Native SwiftUI `Math` view and UIKit/AppKit `MathLabel` / `HostedMathLabel` with reactive environment modifiers.
- **12 Bundled OpenType MATH Fonts**: Complete OpenType MATH font layout engine bundled with 12 fonts (*Latin Modern*, *XITS*, *Asana*, *Euler*, *Fira*, *Garamond*, *Kp Math*, *Lete Sans*, *Libertinus*, *Noto Sans*, and *Termes*).
- **Multi-Format Export**: Render and export math expressions to **Raster PNG** (`MathImage`), **Vector PDF** (`MathPDF`), or **Vector SVG** (`MathSVG` with portable glyph outline paths).
- **Comprehensive TeX Support**: Fractions, radicals, matrices, multi-line environments (`aligned`, `cases`, `gather`, `split`), accent attachments, stretchy delimiters (`\left ... \right`), limits, and user macros (`\newcommand`).
- **Responsive Layout**: Automatic line-breaking across container width constraints (`maxWidth`).

---

## 📦 Installation

Add **SwiftTexMath** via Swift Package Manager in Xcode (**File → Add Package Dependencies…**) or directly in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/twn39/SwiftTexMath.git", branch: "main"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "SwiftTexMath", package: "SwiftTexMath"),
            // Or core/headless library only:
            // .product(name: "SwiftTexMathCore", package: "SwiftTexMath"),
        ]
    ),
]
```

### Products Breakdown

| Target | Role | Description |
|---|---|---|
| 🧱 **`SwiftTexMathCore`** | Headless TeX Pipeline | `MathParser`, `Typesetter`, `MathRenderer`, CoreGraphics drawing, raster/vector exports (`MathImage`, `MathPDF`, `MathSVG`). |
| 🎨 **`SwiftTexMath`** | UI Layer | SwiftUI `Math` view, `MathLabel`, `HostedMathLabel`, environment keys, view modifiers, and layout cache. |

*Dependency direction: `SwiftTexMath` → `SwiftTexMathCore`.*

---

## 🚀 Quick Start

### 1. SwiftUI

```swift
import SwiftUI
import SwiftTexMath

struct EquationView: View {
    var body: some View {
        Math(#"x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}"#)
            .mathFont(MathFont(name: .latinModern, size: 24))
            .mathTypesettingStyle(.display)
            .mathRenderingMode(.monochrome)
    }
}
```

> **Environment Modifiers**: `.mathFont(_:)`, `.mathTypesettingStyle(_:)`, `.mathRenderingMode(_:)`, `.mathFonts(_:)`, `.mathTextFallbackFontName(_:)`.

---

### 2. UIKit / AppKit (`MathLabel`)

```swift
import SwiftTexMath

let label = MathLabel()
label.latex = #"E = mc^2"#
label.mathFont = MathFont(name: .latinModern, size: 24)
label.preferredMaxLayoutWidth = 280

// Or embed in SwiftUI hierarchy:
let hosted = HostedMathLabel(latex: #"E = mc^2"#)
```

---

### 3. Headless Layout & CoreGraphics

```swift
import SwiftTexMathCore

let renderer = MathRenderer()
let display = try renderer.layout(latex: #"E = mc^2"#)
// Draw display list directly into any CGContext:
// CGContext.draw(display, at: origin, foregroundColor: .black, fonts: fontRegistry)
```

---

### 4. Raster & Vector Export

#### 📸 Raster PNG Snapshot (`MathImage`)
```swift
import SwiftTexMathCore

let result = try MathImage.render(latex: #"a^2 + b^2 = c^2"#)
let cgImage = result.image     // CGImage pixel bitmap
let sizePoints = result.size   // Expression bounds in points
```

#### 📄 Vector PDF Export (`MathPDF`)
```swift
import SwiftTexMathCore

let pdfData = try MathPDF.render(latex: #"E = mc^2"#)
// Encapsulated vector PDF data matching formula bounds + padding
```

#### 🎨 Vector SVG Export (`MathSVG`)
```swift
import SwiftTexMathCore

let svgResult = try MathSVG.render(latex: #"E = mc^2"#)
// Full standalone SVG document with self-contained glyph outline paths (no embedded fonts required)
try svgResult.data.write(to: URL(fileURLWithPath: "math.svg"))
```

---

## 🧮 TeX Feature Support

| Category | Features & Commands | Status |
|---|---|:---:|
| **Fractions & Binomials** | `\frac`, `\dfrac`, `\tfrac`, `\cfrac[l\|c\|r]`, `\binom`, `\genfrac`, `\over`, `\atop`, `\choose`, `\brack`, `\brace` | ✅ |
| **Radicals** | `\sqrt{x}`, `\sqrt[n]{x}` (OpenType `v_variants` sizing) | ✅ |
| **Delimiters** | Stretchy delimiters `\left ... \right`, `\middle`, `\big`/`\Big`/`\bigg`/`\Bigg` (with l/r/m variants) | ✅ |
| **Scripts & Limits** | Subscript `_`, Superscript `^`, prime `'`, large operators with `\limits` / `\nolimits` | ✅ |
| **Accents** | `\hat`, `\tilde`, `\bar`, `\vec`, `\dot`, `\ddot`, `\check`, `\breve`, `\acute`, `\grave`, `\widehat`, `\widetilde`, `\utilde`, `\underbar`, `\underrightarrow`, `\underleftarrow`, `\accent`, `\overaccent`, `\underaccent` | ✅ |
| **Spacing & Kerns** | `\,`, `\:`, `\;`, `\!`, `\quad`, `\qquad`, `\kern`, `\hspace`, `\mkern` | ✅ |
| **Styles** | `\displaystyle`, `\textstyle`, `\scriptstyle`, `\scriptscriptstyle` | ✅ |
| **Fonts & Alphabets** | `\mathrm`, `\mathbf`, `\mathit`, `\text`, `\mathsf`/`\textsf`, `\mathtt`/`\texttt`, `\boldsymbol`, `\bf`/`\rm`/`\mit`, `\mathcal`, `\mathscr`, `\mathfrak`, `\mathbb` | ✅ |
| **Matrices & Environments** | `cases`, `pmatrix`, `bmatrix`, `Bmatrix`, `vmatrix`, `Vmatrix`, `array{c\|cr}`, starred `pmatrix*` | ✅ |
| **Multi-line Envs** | `aligned`, `alignedat`, `split`, `gather`, `gathered`, `eqnarray`, `align` | ✅ |
| **Columns & Lines** | `\hline`, vertical lines `|`, `@{...}` column space inserts, `\intertext` | ✅ |
| **Coloring & Framing** | `\color`, `\textcolor`, `\colorbox` (named + `#hex`), `\boxed` | ✅ |
| **Boxes & Stack** | `\phantom`, `\smash`, `\llap`, `\rlap`, `\cancel`, `\sout`, `\overset`, `\underset`, `\stackrel`, `\substack`, `\not=` | ✅ |
| **Macros & Operations** | `\operatorname`/`\operatorname*`, `\pmod`/`\pod`/`\bmod`, `\bra`/`\ket`/`\braket`, `\mathbin`...`\mathpunct`, `\tag` | ✅ |
| **Multi-Integrals** | `\iint`...`\oiint`/`\oiiint`/`\fint`/... | ✅ |
| **AMS Aliases & Custom** | AMS aliases (`\lt`, `\gt`, `\therefore`, `\impliedby`, `\dotsc`), `AtomFactory.addLatexSymbol` | ✅ |
| **User Macros** | `\newcommand` / `\def` (0–9 arguments per parse session) | ✅ |
| **Auto Line-Breaking** | Wrap across relational/binary operators and spaces via `maxWidth` | ✅ |
| **Bundled Fonts** | 12 bundled OpenType MATH fonts (LM, XITS, Asana, Euler, etc.) | ✅ |
| **Vector Export** | Vector PDF (`MathPDF`) & Vector SVG (`MathSVG`) | ✅ |

*Note: Delimiters `$…$`, `$$…$$`, `\(...\)`, `\[…\]` are stripped at parse time and inject an implied style atom.*

### Accent Commands Detail

| Command | Placement | Sizing & Attachment Notes |
|---|---|---|
| `\hat` `\tilde` `\bar` `\vec` `\dot` `\ddot` `\check` `\breve` `\acute` `\grave` | Above base | MATH top accent attachment positioning |
| `\widehat` `\widetilde` | Above base, stretchy | Horizontal variants; assembly when present |
| `\utilde` `\underbar` | Below base | Prefers `*belowcmb` glyphs |
| `\underrightarrow` `\underleftarrow` | Below base, stretchy | Horizontal variants / `h_assembly` |
| `\accent{mark}{base}` `\overaccent{mark}{base}` | Above base | Free-form mark (script size) or bare accent name |
| `\underaccent{mark}{base}` | Below base | Bare accent mark (e.g. `\underaccent{\tilde}{x}`) |

---

## 🏛 Architecture & Design Pipeline

```
  LaTeX String ──> MathParser ──> MathList (AST)
                                      │
                                      ▼
                               MathNormalizer
                                      │
                                      ▼
    DisplayList <── Typesetter (Appendix-G Engine)
        │
        ├──> CGContext / MathLabel / SwiftUI Canvas
        └──> MathImage (PNG) / MathPDF / MathSVG
```

### Core Architecture Breakdown

| Module | Location | Responsibilities |
|---|---|---|
| **Parse** | `Sources/SwiftTexMathCore/Parse/` | Recursive-descent parser & command family modules (`FractionCommands`, `DelimiterCommands`, `MacroCommands+*`). |
| **Syntax** | `Sources/SwiftTexMathCore/Syntax/` | AST structures (`MathAtom`, `MathList`, `AtomFactory`, serializers). |
| **Normalize** | `Sources/SwiftTexMathCore/Normalize/` | Pre-layout AST normalization & semantic lowering (number fusion, Bin→Ord, boundary cleanup). |
| **Layout** | `Sources/SwiftTexMathCore/Layout/` | TeX Appendix-G layout engine (`Typesetter`, `WrapLayout`, `TableLayout`). |
| **Display** | `Sources/SwiftTexMathCore/Display/` | `DisplayList` generation & CoreGraphics path rendering. |
| **Font** | `Sources/SwiftTexMathCore/Font/` | OpenType MATH metric tables, glyph variants/assemblies, `FontRegistry`. |

### Key Invariants

1. **Normalize Before Layout**: `MathNormalizer` handles AST sugar cleanup prior to typesetting. `Typesetter` remains focused purely on layout geometry.
2. **Payload Growth Discipline**: Extend `MathAtom.Payload` only when a construct requires a distinct layout shape. Register new commands in family modules or layout helpers. See [docs/PAYLOAD_CHECKLIST.md](docs/PAYLOAD_CHECKLIST.md).
3. **Font Injection & SwiftUI Cache**: `MathRenderer`, `MathImage`, and `.mathFonts(...)` accept any `FontProviding`. Layout caching occurs only when using `FontRegistry.shared`.

### Error Handling

Parse failures throw `ParseError` containing a strongly typed `Code` (`mismatchedBraces`, `invalidEnvironment`, `missingEnd`, `invalidLimits`). UI surfaces (`Math`, `MathLabel`) render inline fallback error text instead of crashing.

---

## 🔤 Bundled OpenType MATH Fonts

SwiftTexMath includes 12 production-grade OpenType MATH fonts in `mathFonts.bundle`, with full OpenType MATH metrics, glyph variants, and assemblies:

- **Latin Modern Math** *(Default)*
- **Asana Math**
- **Euler Math**
- **Fira Math**
- **Garamond Math**
- **Kp Math**
- **Lete Sans Math**
- **Libertinus Math**
- **Noto Sans Math**
- **Termes Math**
- **XITS Math**

---

## 🧪 Development & Testing

Run unit tests and verification goldens:

```bash
swift test
```

Run the headless command-line demo target:

```bash
# Print formula layout metrics
swift run SwiftTexMathDemo

# Render formula directly to a PNG image file
swift run SwiftTexMathDemo 'E = mc^2' /tmp/math.png
```

### Reference Documentation

- **[docs/KNOWN_LIMITATIONS.md](docs/KNOWN_LIMITATIONS.md)**: Serialization and line-breaking caveats.
- **[docs/layout-geometry-status.md](docs/layout-geometry-status.md)**: Numeric layout geometry status and baselines.
- **[docs/PAYLOAD_CHECKLIST.md](docs/PAYLOAD_CHECKLIST.md)**: Protocol for adding AST payloads.
- **[AGENTS.md](AGENTS.md)** & **[.codegraph/README.md](.codegraph/README.md)**: Knowledge graph navigation and guidelines.

---

## 📄 License

SwiftTexMath is released under the **MIT License**.
