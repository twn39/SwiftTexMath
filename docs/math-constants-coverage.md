# OpenType MATH constants coverage

Audit of MATH table constants consumed by SwiftTexMath vs typical OpenType MATH
keys present in Latin Modern / XITS plists. Update when adding layout that
depends on new constants.

Style routing: [FontMetrics+Style.swift](../Sources/SwiftTexMathCore/Font/FontMetrics+Style.swift)
selects display vs text/script parameter sets.

## Consumed (wired to layout / metrics API)

| Constant | API / use site |
|---|---|
| `AxisHeight` | fractions, large ops, delimiters, tables |
| `FractionNumerator(DisplayStyle)ShiftUp` | `FractionLayout` |
| `FractionDenominator(DisplayStyle)ShiftDown` | `FractionLayout` |
| `FractionNum(DisplayStyle)GapMin` / `FractionNumeratorGapMin` | `FractionLayout` + style helpers |
| `FractionDenom(DisplayStyle)GapMin` / `FractionDenominatorGapMin` | same |
| `FractionRuleThickness` | `FractionLayout` / draw |
| `Radical(DisplayStyle)VerticalGap` | `RadicalLayout` + style helpers |
| `RadicalRuleThickness` / `RadicalExtraAscender` | radical overbar |
| `RadicalKernBefore/AfterDegree` / `RadicalDegreeBottomRaisePercent` | degree root |
| `SuperscriptShiftUp(Cramped)` / `SubscriptShiftDown` | `ScriptLayout` |
| `SuperscriptBottomMin` / `SubscriptTopMax` | scripts |
| `SubSuperscriptGapMin` / `SuperscriptBottomMaxWithSubscript` | dual scripts |
| `SpaceAfterScript` | script advance |
| `Upper/LowerLimitGapMin` / `BaselineRise/DropMin` | large op limits |
| `Overbar/UnderbarVerticalGap` / `RuleThickness` / `UnderbarExtraDescender` | lines / stack |
| `AccentBaseHeight` / `FlattenedAccentBaseHeight` | accents |
| `MinConnectorOverlap` | v/h glyph assembly |
| Italic correction (per-glyph) | integral scripts, accents |
| Top accent attachment (per-glyph) | accent X placement |

## Variants / assembly (table sections, not single constants)

| Section | Use |
|---|---|
| `v_variants` / `v_assembly` | stretchy delimiters, radicals |
| `h_variants` / `h_assembly` | wide accents, arrows, overbrace |

## Known gaps / not yet wired

These often appear in MATH tables; layout may still use fixed ratios or omit them:

| Constant / topic | Current behavior | Priority |
|---|---|---|
| `ScriptPercentScaleDown` / `ScriptScriptPercentScaleDown` | **Wired** via `FontMetrics.sizeMultiplier(for:)` / `styleFontSize(baseSize:style:)`; layout call sites use metrics. `MathStyle.sizeMultiplier` remains fallback only | done |
| `DelimitedSubFormulaMinHeight` | Not used for `\left...\right` target sizing | P2 |
| `DisplayOperatorMinHeight` | Display ops via `largerGlyph` only | P3 |
| `StackTop(DisplayStyle)ShiftUp` / `StackBottom*ShiftDown` / `StackGapMin` | No-rule stacks use fraction gap pair | P2 — binom already uses frac gaps |
| `StretchStack*` | Horizontal stacks use over/under gaps | P3 |
| `FractionNumerator/Denominator(DisplayStyle)GapMin` naming aliases | Covered via FontMetrics aliases | — |
| `RadicalDegreeBottomRaisePercent` | **Used** | — |
| `SkewedFraction*` | Not supported | — |
| `MathLeading` | Wrap baseline skip uses TeX-like rule | P3 |

## Multi-font notes

- All bundled fonts must load with `axisHeight > 0` (`FontMetricsTableTests.bundledFontsLoadMathTables`).
- Clearance **relative** invariants (gap ≥ style min) should hold for LM and XITS;
  absolute sizes differ and must not share a single pt golden.

## When updating

1. New layout constant → add `FontMetrics` accessor + row in “Consumed”.
2. Prefer style-aware helpers over `if style == .display` branches.
3. Add a unit test that the constant is non-zero on Latin Modern @ 20pt when required for geometry.
