# Known limitations

Intentional or temporary gaps in SwiftTexMath. Prefer updating this file when
behavior is approximated rather than fully TeX-faithful.

## Layout

| Topic | Behavior |
|---|---|
| **Auto wrap (`maxWidth`)** | Evaluated via TeX penalties (`relpenalty: 500`, `binoppenalty: 700`), nested delimiter group penalties (`openDepth`), explicit `\allowbreak` / `\nobreak`, and Knuth-Plass badness squared shortfall penalties. Baseline skip uses a TeX-like rule (`~1.2×` font size floor + inter-line gap from MATH `mu`). |
| **`\tag` / `\tag*` / `\notag`** | Tags typeset upright; `\tag` parenthesizes, `\tag*` does not. With `maxWidth > 0`, the tag is **flush-right** on the line; with `maxWidth == 0`, it follows the expression after a thick space. `\notag` suppresses auto-numbering and emits no visible label. |
| **Multi-line tags** | In equation-like envs (`align`/`aligned`/`gather`/`gathered`/`eqnarray`/`equation`/`multline`/`split` and starred/alignat variants), `\tag`/`\notag` are **hoisted out of cells** and placed at the **row margin** (flush-right when `maxWidth > 0`, else after the row body). Matrix-like envs (`pmatrix`, `array`, …) do **not** hoist — tags stay in-cell. |
| **Auto equation numbers** | **Outer** envs (`equation`, `align`, `gather`, `eqnarray`, `multline`) **always** number rows (TeX-like), independent of `numberEquations`. **Inner** envs (`aligned`, `gathered`, `split`) never auto-number. Starred outer envs (`equation*`, `align*`, `gather*`, `multline*`) never auto-number. Free-standing lines still need `MathEnvironment.numberEquations = true`. Numbers share row-margin placement with `\tag`. No page right-margin / document counter. |
| **`\label` / `\ref` / `\eqref`** | `\label{name}` is layout-neutral. A pre-pass binds labels to bare markers from auto-numbers / `\tag` within the **same** layout input; `\ref` / `\eqref` render upright resolved text (or `??` / `(??)` if unbound). No multi-document counters, no `\pageref`, no cleveref. Use `MathRenderer.layoutDetailed` to inspect the label map. |
| **Multi-line envs** | `aligned` / `gather` / `align` / `split` / `equation` / `multline` / … are table-based; `\intertext` is a full-width upright row (not a real text-mode paragraph). |
| **Line breaks in tables** | `\\` is a row break inside environments; paragraph wrap is only via `MathEnvironment.maxWidth`. |
| **Recursion limits** | Parse, typeset, CoreGraphics draw, and SVG emit all depth-cap walks (`MathEnvironment.maxRecursionDepth` / `DisplayTraversal.defaultMaxDepth`, default 128). Pathological nesting returns empty layout or stops drawing rather than overflowing the stack. |

## Serialization

| Topic | Behavior |
|---|---|
| **`LatexSerializer` / `MathList.latexString`** | **Best-effort.** Round-trips common constructs. May lose `\cfrac` alignment, some box/strike details, and exact command aliases. Do not rely on byte-identical source recovery. |

## Fonts & drawing

| Topic | Behavior |
|---|---|
| **Custom `FontProviding` & `FontMetricsProtocol`** | SwiftUI `DisplayProvider` automatically caches parse & layout results for all `FontProviding` instances. Custom metric providers and test doubles conform to `FontMetricsProtocol`. |
| **Missing glyphs** | Falls back to the text fallback font / system UI font (`GlyphRun.usesSystemFallback` / `fallbackFontName`); metrics may not match MATH spacing. Tests: `MissingGlyphHardeningTests`. |
| **Script scale** | Layout uses OpenType `ScriptPercentScaleDown` / `ScriptScriptPercentScaleDown` via `FontMetrics.sizeMultiplier(for:)` (LM: 0.70 / 0.50). `MathStyle.sizeMultiplier` is fallback only when metrics are missing. |
| **External oracle** | KaTeX DomTree (`ExternalGeometryOracleTests` + `scripts/katex_oracle.mjs`). TeX box oracle skeleton (`scripts/tex_oracle/`, `TeXGeometryOracleTests`); fixture defaults to `status=unavailable` without LuaTeX/XeTeX. See [tex-oracle.md](tex-oracle.md). |
| **Multi-font geometry** | Absolute LM 20pt goldens are Latin Modern only. Relative clearances also run on XITS (and smoke on other bundled fonts) via `MultiFontClearanceTests`. |
| **Export** | `MathImage` (bitmap/PNG), `MathPDF` (vector PDF), `MathSVG` (vector SVG via glyph outlines + stroked rules). SVG does not embed font files; missing outline glyphs fall back to system outline then portable `<text>`. |

## UI façade

| Topic | Behavior |
|---|---|
| **`MathLabel` platforms** | UIKit/AppKit only (not watchOS). |
| **Interaction** | No atom hit-testing, selection, or copy-as-LaTeX gesture beyond setting `accessibilityLabel` to the source string. |
| **Accessibility** | Host UI still prefers the LaTeX source string. Core also exposes `DisplayList.accessibilityPlainText` (glyph-order best-effort, not a full spoken math tree / MathML). |

## Macros & language surface

| Topic | Behavior |
|---|---|
| **User macros** | `\newcommand` / `\renewcommand` / `\providecommand` / `\def` with 0–9 parameters and `#1`…`#9` (`##` → `#`). In-source definitions remain **parse-session scoped**. Cross-parse macros: pass `userMacros:` to `MathParser.parse` or set `MathRenderer.userMacros` / `defineMacro(_:parameterCount:replacement:)`. No optional args, no `\edef`/`\let`, no delimited parameters. |
| **`\intertext`** | Supported inside `align` / `aligned` / `gather` / `gathered` / `eqnarray` / `split` / `alignedat` as a full-width upright text row. Not a real text-mode paragraph (uses math upright styling). |
| **Full TeX** | Math-mode subset only (no text-mode paragraphs, no TikZ, no packages). |

## Tests & platforms

| Topic | Behavior |
|---|---|
| **Golden PNGs** | Tolerant pixel match (AA variance). Prefer running goldens on CI macOS. Expanded catalog (~33 fixtures) covers binom, limits, cases, tags, etc. |
| **Geometry goldens** | Absolute sizes at Latin Modern 20pt; core set in `LayoutGeometryTests` (±0.02) plus broad catalog in `BroadLayoutValidationTests` (±0.05). See [layout-geometry-status.md](layout-geometry-status.md). |
| **Style-aware MATH gaps** | Display vs text/script constants via `FontMetrics` helpers (`fraction*GapMin(for:)`, `radicalVerticalGap(for:)`). Nested radicals under text-style numerators use **text** radical gaps (correct TeX behavior), not display. |
| **Binom / atop stacks** | Zero-thickness genfrac validates **stack separation** (`numGap+denGap`), not fraction-rule clearance. |
| **Multi-layer validation** | Size + structure/tokens + style-aware MATH clearance + nested corpus + ink projection + raster fingerprints + KaTeX soft bands + tex2math corpus. Not pixel-identical to TeX/KaTeX. |
