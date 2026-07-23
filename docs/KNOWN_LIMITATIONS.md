# Known limitations

Intentional or temporary gaps in SwiftTexMath. Prefer updating this file when
behavior is approximated rather than fully TeX-faithful.

## Layout

| Topic | Behavior |
|---|---|
| **Auto wrap (`maxWidth`)** | Breaks prefer relations, binary ops, and spaces; mid-letter breaks are last resort. Baseline skip uses a TeX-like rule (`~1.2×` font size floor + inter-line gap from MATH `mu`), not full TeX demerits / `\baselineskip` glue. |
| **`\tag` / `\tag*`** | Tags typeset upright; `\tag` parenthesizes, `\tag*` does not. With `maxWidth > 0`, the tag is **flush-right** on the line; with `maxWidth == 0`, it follows the expression after a thick space. No equation counter, `\notag`, or multi-line equation-number placement. |
| **Multi-line envs** | `aligned` / `gather` / `align` / `split` / … are table-based; not full amsmath numbering or `\intertext`. |
| **Line breaks in tables** | `\\` is a row break inside environments; paragraph wrap is only via `MathEnvironment.maxWidth`. |

## Serialization

| Topic | Behavior |
|---|---|
| **`LatexSerializer` / `MathList.latexString`** | **Best-effort.** Round-trips common constructs. May lose `\cfrac` alignment, some box/strike details, and exact command aliases. Do not rely on byte-identical source recovery. |

## Fonts & drawing

| Topic | Behavior |
|---|---|
| **Custom `FontProviding`** | SwiftUI `DisplayProvider` caches **only** when the provider is identity-equal to `FontRegistry.shared`. Custom providers recompute every pass. |
| **Missing glyphs** | Falls back to the text fallback font / system UI font; metrics may not match MATH spacing. |
| **Export** | `MathImage` (bitmap/PNG), `MathPDF` (vector PDF), `MathSVG` (vector SVG via glyph outlines + stroked rules). SVG does not embed font files; missing outline glyphs may fall back to `<text>`. |

## UI façade

| Topic | Behavior |
|---|---|
| **`MathLabel` platforms** | UIKit/AppKit only (not watchOS). |
| **Interaction** | No atom hit-testing, selection, or copy-as-LaTeX gesture beyond setting `accessibilityLabel` to the source string. |
| **Accessibility** | Labels expose the LaTeX source string; there is no spoken math tree. |

## Macros & language surface

| Topic | Behavior |
|---|---|
| **User macros** | `\newcommand` / `\renewcommand` / `\providecommand` / `\def` with 0–9 parameters and `#1`…`#9` (`##` → `#`). **Parse-session scoped** (not global across `MathParser.parse` calls). No optional args, no `\edef`/`\let`, no delimited parameters. |
| **`\intertext`** | Supported inside `align` / `aligned` / `gather` / `gathered` / `eqnarray` / `split` / `alignedat` as a full-width upright text row. Not a real text-mode paragraph (uses math upright styling). |
| **Full TeX** | Math-mode subset only (no text-mode paragraphs, no TikZ, no packages). |

## Tests & platforms

| Topic | Behavior |
|---|---|
| **Golden PNGs** | Tolerant pixel match (AA variance). Prefer running goldens on CI macOS. |
| **Geometry goldens** | Absolute sizes at Latin Modern 20pt; see [layout-geometry-status.md](layout-geometry-status.md). |
