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
| `DelimitedSubFormulaMinHeight` | `DelimiterLayout` — floor for `\left...\right` when content height ≥ constant |
| `DisplayOperatorMinHeight` | `LargeOperatorLayout` — pick display vertical variant that clears min when possible |
| `StackTop(DisplayStyle)ShiftUp` / `StackBottom*ShiftDown` / `Stack(DisplayStyle)GapMin` | `FractionLayout` no-rule path (`\atop` / `\binom` / `\choose`) via style helpers |
| `StretchStackGapAboveMin` / `StretchStackGapBelowMin` | `StackLayout` for stretchy nuclei (`\overbrace`, `\overrightarrow`, …) |
| `StretchStackTopShiftUp` / `StretchStackBottomShiftDown` | Exposed on `FontMetrics`; not applied as absolute offsets (collides with multi-part underbrace/overbrace + scripts) |
| `MathLeading` | `WrapLayout` inter-line gap (with mu floor) |

## Variants / assembly (table sections, not single constants)

| Section | Use |
|---|---|
| `v_variants` / `v_assembly` | stretchy delimiters, radicals |
| `h_variants` / `h_assembly` | wide accents, arrows, overbrace |

## Known gaps / not yet wired

These often appear in MATH tables; layout may still use fixed ratios or omit them:

| Constant / topic | Current behavior | Priority |
|---|---|---|
| `ScriptPercentScaleDown` / `ScriptScriptPercentScaleDown` | **Wired** via `FontMetrics.sizeMultiplier(for:)` / `styleFontSize(baseSize:style:)` | done |
| `DelimitedSubFormulaMinHeight` | **Wired** (tall-content floor only; small `\left(x\right)` keeps TeX factor/shortfall) | done |
| `DisplayOperatorMinHeight` | **Wired** (variant selection); may still undershoot if no variant is tall enough | done (soft) |
| `Stack*` no-rule | **Wired** in `FractionLayout` | done |
| `StretchStackGap*` | **Wired** for stretchy nuclei gaps | done |
| `StretchStackTop/BottomShift*` | Accessors only; gap placement remains primary | P3 refine |
| `FractionNumerator/Denominator(DisplayStyle)GapMin` naming aliases | Covered via FontMetrics aliases | — |
| `RadicalDegreeBottomRaisePercent` | **Used** | — |
| `SkewedFraction*` | Not supported | P3 / product |
| `MathLeading` | **Wired** in wrap inter-line gap | done |

## Multi-font notes

- All bundled fonts must load with `axisHeight > 0` (`FontMetricsTableTests.bundledFontsLoadMathTables`).
- Clearance **relative** invariants (gap ≥ style min) should hold for LM and XITS;
  absolute sizes differ and must not share a single pt golden.

## When updating

1. New layout constant → add `FontMetrics` accessor + row in “Consumed”.
2. Prefer style-aware helpers over `if style == .display` branches.
3. Add a unit test that the constant is non-zero on Latin Modern @ 20pt when required for geometry.
