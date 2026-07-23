@preconcurrency import CoreGraphics
@preconcurrency import CoreText
import Foundation

/// Vertical glyph assembly part from the OpenType MATH table.
struct GlyphPart: Sendable {
    var glyph: CGGlyph
    var fullAdvance: CGFloat
    var startConnectorLength: CGFloat
    var endConnectorLength: CGFloat
    var isExtender: Bool
}

/// Result of sizing a delimiter / radical to a target height.
struct SizedGlyph: Sendable {
    var glyphIDs: [CGGlyph]
    var offsetsY: [CGFloat]
    var ascent: CGFloat
    var descent: CGFloat
    var width: CGFloat
}

/// Scaled MATH metrics for a concrete `(font, size)`.
public struct FontMetrics: Sendable {
    private let font: MathFont
    private let unitsPerEm: UInt
    private let table: FontTable
    let ctFont: CTFont
    let cgFont: CGFont

    init(font: MathFont, unitsPerEm: UInt, table: FontTable, ctFont: CTFont, cgFont: CGFont) {
        self.font = font
        self.unitsPerEm = unitsPerEm
        self.table = table
        self.ctFont = ctFont
        self.cgFont = cgFont
    }

    public var mathUnit: CGFloat { font.size / 18 }
    public var size: CGFloat { font.size }

    func unitsToPoints(_ value: Int) -> CGFloat {
        CGFloat(value) * font.size / CGFloat(unitsPerEm)
    }

    func constant(named name: String) -> CGFloat {
        unitsToPoints(table.constants[name] ?? 0)
    }

    func glyph(for nucleus: String) -> CGGlyph {
        var chars = Array(nucleus.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        CTFontGetGlyphsForCharacters(ctFont, &chars, &glyphs, chars.count)
        return glyphs.first ?? 0
    }

    func glyphName(for glyph: CGGlyph) -> String {
        (cgFont.name(for: glyph) as String?) ?? ""
    }

    func glyphID(named name: String) -> CGGlyph {
        cgFont.getGlyphWithGlyphName(name: name as CFString)
    }

    func advances(forGlyphs glyphs: [CGGlyph]) -> [CGSize] {
        var advances = [CGSize](repeating: .zero, count: glyphs.count)
        CTFontGetAdvancesForGlyphs(ctFont, .horizontal, glyphs, &advances, glyphs.count)
        return advances
    }

    func boundingRects(forGlyphs glyphs: [CGGlyph]) -> [CGRect] {
        var rects = [CGRect](repeating: .zero, count: glyphs.count)
        CTFontGetBoundingRectsForGlyphs(ctFont, .horizontal, glyphs, &rects, glyphs.count)
        return rects
    }

    func measure(_ text: String) -> (width: CGFloat, ascent: CGFloat, descent: CGFloat) {
        let glyphs = text.map { glyph(for: String($0)) }
        return measure(glyphs: glyphs)
    }

    func measure(glyphs: [CGGlyph]) -> (width: CGFloat, ascent: CGFloat, descent: CGFloat) {
        guard !glyphs.isEmpty else { return (0, 0, 0) }
        let advances = advances(forGlyphs: glyphs)
        let bounds = boundingRects(forGlyphs: glyphs)
        let width = advances.reduce(CGFloat(0)) { $0 + $1.width }
        let ascent = bounds.map(\.maxY).max() ?? CTFontGetAscent(ctFont)
        let descent = -(bounds.map(\.minY).min() ?? -CTFontGetDescent(ctFont))
        return (width, max(ascent, 0), max(descent, 0))
    }

    func italicCorrection(for glyph: CGGlyph) -> CGFloat {
        let name = glyphName(for: glyph)
        guard let units = table.italic[name] else { return 0 }
        return unitsToPoints(units)
    }

    func italicCorrection(forNucleus nucleus: String) -> CGFloat {
        guard !nucleus.isEmpty else { return 0 }
        return italicCorrection(for: glyph(for: nucleus))
    }

    func topAccentAdjustment(for glyph: CGGlyph) -> CGFloat {
        let name = glyphName(for: glyph)
        if let units = table.accents[name] {
            return unitsToPoints(units)
        }
        let advances = advances(forGlyphs: [glyph])
        return (advances.first?.width ?? 0) / 2
    }

    var minConnectorOverlap: CGFloat { constant(named: "MinConnectorOverlap") }
    var accentBaseHeight: CGFloat { constant(named: "AccentBaseHeight") }

    // MARK: - Variants / assembly

    func verticalVariantNames(for glyph: CGGlyph) -> [String] {
        let name = glyphName(for: glyph)
        if let variants = table.vVariants[name], !variants.isEmpty {
            return variants
        }
        return name.isEmpty ? [] : [name]
    }

    func verticalVariants(for glyph: CGGlyph) -> [CGGlyph] {
        verticalVariantNames(for: glyph).map { glyphID(named: $0) }
    }

    func largerGlyph(_ glyph: CGGlyph, forDisplayStyle: Bool) -> CGGlyph {
        let variants = verticalVariants(for: glyph)
        guard variants.count > 1 else { return glyph }
        if forDisplayStyle {
            let count = variants.count
            let targetIndex: Int
            if count <= 2 {
                targetIndex = count - 1
            } else if count <= 4 {
                targetIndex = count - 2
            } else {
                targetIndex = min(count - 2, Int(Double(count) * 0.6))
            }
            return variants[targetIndex]
        }
        return variants.first(where: { $0 != glyph }) ?? glyph
    }

    func verticalAssembly(for glyph: CGGlyph) -> [GlyphPart] {
        let name = glyphName(for: glyph)
        guard let assembly = table.vAssembly[name] else { return [] }
        return assembly.parts.map { part in
            GlyphPart(
                glyph: glyphID(named: part.glyph),
                fullAdvance: unitsToPoints(part.advance),
                startConnectorLength: unitsToPoints(part.startConnector),
                endConnectorLength: unitsToPoints(part.endConnector),
                isExtender: part.extender
            )
        }
    }

    /// Pick the smallest vertical variant whose height covers `height`, else the largest.
    func findVerticalVariant(
        _ glyph: CGGlyph,
        coveringHeight height: CGFloat
    ) -> SizedGlyph {
        let variants = verticalVariants(for: glyph)
        let glyphs = variants.isEmpty ? [glyph] : variants
        var last = SizedGlyph(glyphIDs: [glyphs[0]], offsetsY: [], ascent: 0, descent: 0, width: 0)

        for g in glyphs {
            let m = measure(glyphs: [g])
            last = SizedGlyph(
                glyphIDs: [g],
                offsetsY: [],
                ascent: m.ascent,
                descent: m.descent,
                width: m.width
            )
            if m.ascent + m.descent >= height {
                return last
            }
        }
        return last
    }

    /// Build a stretchy delimiter from `v_assembly` parts when variants are not tall enough.
    func constructVerticalGlyph(_ glyph: CGGlyph, height glyphHeight: CGFloat) -> SizedGlyph? {
        let parts = verticalAssembly(for: glyph)
        guard !parts.isEmpty else { return nil }

        for numExtenders in 0..<100 {
            var glyphsRv: [CGGlyph] = []
            var offsetsRv: [CGFloat] = []
            var prev: GlyphPart?
            let minDistance = minConnectorOverlap
            var minOffset: CGFloat = 0
            var maxDelta = CGFloat.greatestFiniteMagnitude

            for part in parts {
                let repeats = part.isExtender ? numExtenders : 1
                for _ in 0..<repeats {
                    glyphsRv.append(part.glyph)
                    if let prev {
                        let maxOverlap = min(prev.endConnectorLength, part.startConnectorLength)
                        let minOffsetDelta = prev.fullAdvance - maxOverlap
                        let maxOffsetDelta = prev.fullAdvance - minDistance
                        maxDelta = min(maxDelta, maxOffsetDelta - minOffsetDelta)
                        minOffset += minOffsetDelta
                    }
                    offsetsRv.append(minOffset)
                    prev = part
                }
            }

            guard let prev else { continue }
            let minHeight = minOffset + prev.fullAdvance
            let maxHeight = minHeight + maxDelta * CGFloat(max(glyphsRv.count - 1, 0))

            if minHeight >= glyphHeight {
                let width = advances(forGlyphs: [glyphsRv[0]]).first?.width ?? 0
                return SizedGlyph(
                    glyphIDs: glyphsRv,
                    offsetsY: offsetsRv,
                    ascent: minHeight,
                    descent: 0,
                    width: width
                )
            }

            if glyphHeight <= maxHeight, glyphsRv.count > 1 {
                let delta = glyphHeight - minHeight
                let deltaIncrease = delta / CGFloat(glyphsRv.count - 1)
                var lastOffset: CGFloat = 0
                for i in offsetsRv.indices {
                    offsetsRv[i] += CGFloat(i) * deltaIncrease
                    lastOffset = offsetsRv[i]
                }
                let width = advances(forGlyphs: [glyphsRv[0]]).first?.width ?? 0
                return SizedGlyph(
                    glyphIDs: glyphsRv,
                    offsetsY: offsetsRv,
                    ascent: lastOffset + prev.fullAdvance,
                    descent: 0,
                    width: width
                )
            }
        }
        return nil
    }

    /// TeX `\left`/`\right` delimiter covering `height`, preferring variants then assembly.
    func sizedDelimiter(forNucleus nucleus: String, height: CGFloat) -> SizedGlyph {
        let base = glyph(for: nucleus)
        let variant = findVerticalVariant(base, coveringHeight: height)
        if variant.ascent + variant.descent + 0.1 >= height {
            return variant
        }
        if let assembled = constructVerticalGlyph(base, height: height) {
            return assembled
        }
        return variant
    }

    /// Radical glyph covering `height` (variants, then base).
    func sizedRadical(height: CGFloat) -> SizedGlyph {
        let base = glyph(for: "\u{221A}")
        return findVerticalVariant(base, coveringHeight: height)
    }

    // Fractions
    var fractionNumeratorDisplayStyleShiftUp: CGFloat { constant(named: "FractionNumeratorDisplayStyleShiftUp") }
    var fractionNumeratorShiftUp: CGFloat { constant(named: "FractionNumeratorShiftUp") }
    var fractionDenominatorDisplayStyleShiftDown: CGFloat { constant(named: "FractionDenominatorDisplayStyleShiftDown") }
    var fractionDenominatorShiftDown: CGFloat { constant(named: "FractionDenominatorShiftDown") }
    var fractionNumeratorDisplayStyleGapMin: CGFloat { constant(named: "FractionNumDisplayStyleGapMin") }
    var fractionNumeratorGapMin: CGFloat { constant(named: "FractionNumeratorGapMin") }
    var fractionDenominatorDisplayStyleGapMin: CGFloat { constant(named: "FractionDenomDisplayStyleGapMin") }
    var fractionDenominatorGapMin: CGFloat { constant(named: "FractionDenominatorGapMin") }
    var fractionRuleThickness: CGFloat { constant(named: "FractionRuleThickness") }

    // Scripts
    var superscriptShiftUp: CGFloat { constant(named: "SuperscriptShiftUp") }
    var superscriptShiftUpCramped: CGFloat { constant(named: "SuperscriptShiftUpCramped") }
    var subscriptShiftDown: CGFloat { constant(named: "SubscriptShiftDown") }
    var superscriptBottomMin: CGFloat { constant(named: "SuperscriptBottomMin") }
    var subscriptTopMax: CGFloat { constant(named: "SubscriptTopMax") }
    var subSuperscriptGapMin: CGFloat { constant(named: "SubSuperscriptGapMin") }
    var superscriptBottomMaxWithSubscript: CGFloat { constant(named: "SuperscriptBottomMaxWithSubscript") }
    var spaceAfterScript: CGFloat { constant(named: "SpaceAfterScript") }

    // Radicals
    var radicalExtraAscender: CGFloat { constant(named: "RadicalExtraAscender") }
    var radicalRuleThickness: CGFloat { constant(named: "RadicalRuleThickness") }
    var radicalDisplayStyleVerticalGap: CGFloat { constant(named: "RadicalDisplayStyleVerticalGap") }
    var radicalVerticalGap: CGFloat { constant(named: "RadicalVerticalGap") }
    var radicalKernBeforeDegree: CGFloat { constant(named: "RadicalKernBeforeDegree") }
    var radicalKernAfterDegree: CGFloat { constant(named: "RadicalKernAfterDegree") }

    // Limits
    var upperLimitGapMin: CGFloat { constant(named: "UpperLimitGapMin") }
    var lowerLimitGapMin: CGFloat { constant(named: "LowerLimitGapMin") }
    var upperLimitBaselineRiseMin: CGFloat { constant(named: "UpperLimitBaselineRiseMin") }
    var lowerLimitBaselineDropMin: CGFloat { constant(named: "LowerLimitBaselineDropMin") }

    // Axis
    var axisHeight: CGFloat { constant(named: "AxisHeight") }

    var overbarVerticalGap: CGFloat { constant(named: "OverbarVerticalGap") }
    var overbarRuleThickness: CGFloat { constant(named: "OverbarRuleThickness") }
    var underbarVerticalGap: CGFloat { constant(named: "UnderbarVerticalGap") }
    var underbarRuleThickness: CGFloat { constant(named: "UnderbarRuleThickness") }
    /// TeX ξ₈ — extra descender below the underline rule.
    var underbarExtraDescender: CGFloat { constant(named: "UnderbarExtraDescender") }
}
