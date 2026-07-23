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

## Clearance invariants (MATH-driven)

These assert **gaps**, not absolute sizes:

- Fraction numerator / denominator vs rule (`Fraction*GapMin`)
- Radical overbar vs radicand (`Radical*VerticalGap`)
- Overline / underline vs content (`OverbarVerticalGap` / `UnderbarVerticalGap`)
- Large-op nucleus centered on math axis; limit gaps (`Upper/LowerLimitGapMin`)
- Dual scripts `x_i^j` (`SubSuperscriptGapMin`)
- `\overset` over base (max of overbar / upper-limit gaps)
- `\sout` strike on math axis

## When to update

1. Change typesetting that affects LM 20pt display metrics → update
   `LayoutGeometryTests` expectations **and** this table.
2. Prefer clearance tests for new constructs (stable across small metric tweaks).
3. Golden PNGs under `Tests/SwiftTexMathCoreTests/Goldens/` are a second signal;
   regenerate with the project’s golden update path when intentional.

## Related

- [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) — wrap, tag, serializer caveats
- `LayoutClearanceHelpers.swift` — helpers for tree inspection in tests
