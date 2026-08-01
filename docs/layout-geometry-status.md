# Layout geometry status

Numeric layout expectations for **Latin Modern Math @ 20pt, display style**,
enforced by `Tests/SwiftTexMathCoreTests/LayoutGeometryTests.swift`.

Tolerance: **±0.02** pt on size triples (ascent / descent / width), with a few
clearance tests using MATH table minima (+0.01 slack).

## Size goldens (representative)

| Expression | Ascent | Descent | Width | Notes |
|---|---:|---:|---:|---|
| `x` | 8.84 | 0.22 | 11.44 | Single variable |
| `xyzw` | 8.84 | 4.10 | 44.86 | Descender on `y` |
| `xy2w` | 13.32 | 4.10 | 45.56 | Digit raises ascent |
| `\frac{1}{2}` | 26.86 | 13.72 | 10.0 | Display fraction |
| `\sqrt{2}` | 17.88 | 2.92 | 26.66 | Radical + overbar |
| `\sqrt[3]{x}` | 13.40 | 7.40 | 27.54 | Degree root |
| `\hat{x}` | 14.68 | 0.22 | 11.86 | Accent attachment |
| `x+y` | 11.66 | 4.10 | ~45.69 | Operator spacing |
| `a=b` | 13.88 | 0.22 | ~45.83 | Relation spacing |
| `x^2` | 16.584 | 0.22 | 19.56 | Superscript |
| `\sum_{i=1}^{n}` | 29.342 | 21.818 | 28.88 | Limits + axis center |
| `\lim_{x\to\infty}` | 11.94 | 12.574 | ~36.01 | Op with subscript |
| `\displaystyle\int_0^1` | 34.384 | 24.408 | 39.92 | Display integral |
| `\left(\frac{a}{b}\right)` | 22.92 | 13.94 | ~38.90 | Stretchy delims |
| `\overline{abc}` | 17.08 | 0.22 | 27.82 | Overline rule |
| `\underline{abc}` | 13.88 | 4.22 | 27.82 | Underline rule |
| `\widehat{xyz}` | 14.96 | 4.10 | 31.62 | Wide accent variant |
| `x_i^j` | 17.48 | 8.22 | 18.33 | Dual scripts |
| `\begin{pmatrix} a & b \\ c & d \end{pmatrix}` | 25.92 | 15.92 | ~71.94 | Matrix centered on math axis |

### Broad catalog (±0.05 pt)

Extended table-driven goldens live in
`Tests/SwiftTexMathCoreTests/BroadLayoutValidationTests.swift` (`BroadLayoutCatalog`,
70+ formulas). Representative entries (LM Math @ 20pt display):

| Expression | Ascent | Descent | Width |
|---|---:|---:|---:|
| `\binom{n}{k}` | 22.38 | 13.94 | 12.00 |
| `\dfrac{a}{b}` | 22.38 | 13.94 | 10.58 |
| `\tfrac{a}{b}` | 14.07 | 7.05 | 7.41 |
| `\prod_{i=1}^{n}` | 29.34 | 21.82 | 25.56 |
| `\sqrt{\frac{a}{b}}` | 26.94 | 21.86 | 30.58 |
| `\begin{bmatrix}1&2\\3&4\end{bmatrix}` | 26.00 | 16.00 | 64.40 |
| `\begin{cases}…\end{cases}` | 29.00 | 19.00 | 103.43 |
| `\underbrace{a+b+c}_{3}` | 13.88 | 20.65 | 88.24 |
| `\sin^2\theta+\cos^2\theta=1` | 18.84 | 1.68 | 154.87 |
| quadratic formula | 37.18 | 13.94 | 159.57 |

Layers exercised by the broad suite:

1. Absolute size goldens  
2. Display-tree structure + token hints  
3. Fraction / radical MATH clearances (subset)  
4. Raster checksum determinism  
5. Relative style / wrap / export (SVG/PDF) invariants  

Also expanded: PNG goldens (`Goldens/`), fingerprint bands
(`SnapshotFingerprintTests`), KaTeX cross-validation soft bands, and
tex2math corpus deep structure/ink checks.

## Clearance invariants (MATH-driven)

These assert **gaps** and **alignments**, not absolute sizes.

Style selection (`FontMetrics+Style.swift`): **display** uses `*DisplayStyle*`
constants; **text / script / scriptscript** share the non-display set.

- Fraction numerator / denominator vs rule (`fraction*GapMin(for: style)`)
- Zero-thickness genfrac (`\binom` / `\atop` / `\choose`): **stack gap**
  `≥ StackGapMin` / `StackDisplayStyleGapMin` (OpenType Stack\*; not rule clearance)
- Radical overbar vs radicand (`radicalVerticalGap(for: style)`)
- Nested corpus (Phase 1): `\sqrt{\frac{a}{b}}`, `\frac{\sqrt{a}}{\sqrt{b}}`,
  deep fractions, quadratic formula, matrix/pmatrix with fractions, aligned
  — see `NestedGeometryHardeningTests.swift`
- Overline / underline vs content (`OverbarVerticalGap` / `UnderbarVerticalGap`)
- Large-op nucleus centered on math axis; limit gaps (`Upper/LowerLimitGapMin`)
- Dual scripts `x_i^j` (`SubSuperscriptGapMin`)
- `\overset` over base (max of overbar / upper-limit gaps)
- `\sout` strike on math axis
- Matrix/Table vertical center aligned on math axis (`axisHeight`)
- Sized delimiters (`\big`, `\Big`, `\left...\right`) centered on math axis
- Accent attachment points (`accentAttachmentX`) aligned with base attachment points
- Integral / large operator side-scripts tuck subscript leftward by italic correction (`\int_0^1`)
- Matrix inter-row spacing maintains minimum vertical clearance (`OverbarVerticalGap`)
- Stretchy horizontal assemblies (`\overrightarrow`, `\overbrace`) scale width monotonically with base
- Phantom and Smash box invariants (`\phantom`, `\hphantom`, `\vphantom`, `\smash`, `\smash[t]`, `\smash[b]`)
- WrapLayout penalizes breaks inside nested groups so multi-line wrap prefers top-level operators
- **Ink projection** (PNG @ 3×): fraction rules, radical overbars (incl. nested √+frac),
  array hlines, quadratic formula — `InkProjectionClearanceTests`

## When to update

1. Change typesetting that affects LM 20pt display metrics → update
   `LayoutGeometryTests` expectations **and** this table.
2. Prefer clearance tests for new constructs (stable across small metric tweaks).
3. Golden PNGs under `Tests/SwiftTexMathCoreTests/Goldens/` are a second signal;
   regenerate with the project’s golden update path when intentional.
4. New MATH constants → [math-constants-coverage.md](math-constants-coverage.md).
5. Stretchy / multi-font changes → `StretchyAssemblyHardeningTests`,
   `MultiFontClearanceTests` (relative gaps, not absolute pt).
6. External engine bands → [tex-oracle.md](tex-oracle.md); regenerate KaTeX fixture with
   `node scripts/katex_oracle.mjs -o Tests/.../katex_oracle_metrics.json`.

## Related

- [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) — wrap, tag, serializer caveats
- [math-constants-coverage.md](math-constants-coverage.md) — MATH table wiring audit
- [tex-oracle.md](tex-oracle.md) — KaTeX/TeX external geometry oracle
- `LayoutClearanceHelpers.swift` — helpers for tree inspection in tests
- `NestedGeometryHardeningTests.swift` — Phase-1 nested clearance corpus
- `ScriptScaleAndOracleTests.swift` — MATH script scale + KaTeX graded bands
