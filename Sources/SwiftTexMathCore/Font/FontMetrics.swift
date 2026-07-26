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

/// Result of sizing a delimiter / radical / stretchy accent to a target size.
struct SizedGlyph: Sendable {
    var glyphIDs: [CGGlyph]
    /// Per-glyph y offsets for vertical assembly (empty for single glyphs / horizontal).
    var offsetsY: [CGFloat]
    /// Per-glyph x offsets for horizontal assembly (empty for single glyphs / vertical).
    var offsetsX: [CGFloat]
    var ascent: CGFloat
    var descent: CGFloat
    var width: CGFloat

    init(
        glyphIDs: [CGGlyph],
        offsetsY: [CGFloat] = [],
        offsetsX: [CGFloat] = [],
        ascent: CGFloat,
        descent: CGFloat,
        width: CGFloat
    ) {
        self.glyphIDs = glyphIDs
        self.offsetsY = offsetsY
        self.offsetsX = offsetsX
        self.ascent = ascent
        self.descent = descent
        self.width = width
    }
}

/// Scaled MATH metrics for a concrete `(font, size)`.
public struct FontMetrics: Sendable, FontMetricsProtocol {
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

    public func unitsToPoints(_ value: Int) -> CGFloat {
        CGFloat(value) * font.size / CGFloat(unitsPerEm)
    }

    public func constant(named name: String) -> CGFloat {
        unitsToPoints(table.constants[name] ?? 0)
    }

    /// Unitless percent constants from the MATH table (e.g. 60 → 0.60).
    public func percentConstant(named name: String) -> CGFloat {
        CGFloat(table.constants[name] ?? 0) / 100
    }

    public func glyph(for nucleus: String) -> CGGlyph {
        glyphs(for: nucleus).first ?? 0
    }

    public func glyphs(for text: String) -> [CGGlyph] {
        var chars = Array(text.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        CTFontGetGlyphsForCharacters(ctFont, &chars, &glyphs, chars.count)
        return glyphs
    }

    public func glyphName(for glyph: CGGlyph) -> String {
        (cgFont.name(for: glyph) as String?) ?? ""
    }

    public func glyphID(named name: String) -> CGGlyph {
        cgFont.getGlyphWithGlyphName(name: name as CFString)
    }

    public func advances(forGlyphs glyphs: [CGGlyph]) -> [CGSize] {
        var advances = [CGSize](repeating: .zero, count: glyphs.count)
        CTFontGetAdvancesForGlyphs(ctFont, .horizontal, glyphs, &advances, glyphs.count)
        return advances
    }

    public func boundingRects(forGlyphs glyphs: [CGGlyph]) -> [CGRect] {
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

    public func italicCorrection(for glyph: CGGlyph) -> CGFloat {
        let name = glyphName(for: glyph)
        guard let units = table.italic[name] else { return 0 }
        return unitsToPoints(units)
    }

    func italicCorrection(forNucleus nucleus: String) -> CGFloat {
        guard !nucleus.isEmpty else { return 0 }
        return italicCorrection(for: glyph(for: nucleus))
    }

    /// Horizontal accent attachment from the MATH `accents` table (signed, font-relative).
    /// Combining marks often store a negative X (left of origin). Missing → advance/2.
    public func topAccentAdjustment(for glyph: CGGlyph) -> CGFloat {
        accentAttachmentX(for: glyph)
    }

    /// Horizontal attachment point for top or bottom accents.
    /// iosMath-style plists use one `accents` map for both; bottom combining forms
    /// (`*belowcmb`, under-arrows) share the same keys when present.
    func accentAttachmentX(for glyph: CGGlyph) -> CGFloat {
        let name = glyphName(for: glyph)
        if let units = table.accents[name] {
            return unitsToPoints(units)
        }
        // Alias: bare name ↔ combining form.
        for key in [name + "cmb", name + "comb", name + "belowcmb"] where !key.isEmpty {
            if let units = table.accents[key] {
                return unitsToPoints(units)
            }
        }
        let advances = advances(forGlyphs: [glyph])
        return (advances.first?.width ?? 0) / 2
    }

    /// Whether the MATH table has an explicit attachment entry for this glyph.
    func hasAccentAttachment(for glyph: CGGlyph) -> Bool {
        let name = glyphName(for: glyph)
        if table.accents[name] != nil { return true }
        for key in [name + "cmb", name + "comb", name + "belowcmb"] {
            if table.accents[key] != nil { return true }
        }
        return false
    }

    var minConnectorOverlap: CGFloat { constant(named: "MinConnectorOverlap") }
    var accentBaseHeight: CGFloat { constant(named: "AccentBaseHeight") }
    var flattenedAccentBaseHeight: CGFloat { constant(named: "FlattenedAccentBaseHeight") }

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

    /// Horizontal stretch variants (wide accents, stretchy overlays).
    func horizontalVariantNames(for glyph: CGGlyph) -> [String] {
        let name = glyphName(for: glyph)
        guard !name.isEmpty else { return [] }
        // MATH tables often list combining forms (`circumflexcmb`) while CT resolves
        // U+0302 to `circumflex` — try common aliases.
        let candidates = [
            name,
            name + "cmb",
            name + "comb",
            name.hasSuffix("cmb") ? String(name.dropLast(3)) : name
        ]
        var seen = Set<String>()
        for key in candidates where seen.insert(key).inserted {
            if let variants = table.hVariants[key], !variants.isEmpty {
                return variants
            }
        }
        return [name]
    }

    func horizontalVariants(for glyph: CGGlyph) -> [CGGlyph] {
        horizontalVariantNames(for: glyph)
            .map { glyphID(named: $0) }
            .filter { $0 != 0 }
    }

    /// Smallest horizontal variant whose advance covers `width`, else the widest.
    func findHorizontalVariant(
        _ glyph: CGGlyph,
        coveringWidth width: CGFloat
    ) -> (glyph: CGGlyph, width: CGFloat, ascent: CGFloat, descent: CGFloat) {
        let sized = findHorizontalVariantSized(glyph, coveringWidth: width)
        let g = sized.glyphIDs.first ?? glyph
        return (g, sized.width, sized.ascent, sized.descent)
    }

    /// Smallest horizontal variant covering `width` (single glyph, no assembly).
    func findHorizontalVariantSized(
        _ glyph: CGGlyph,
        coveringWidth width: CGFloat
    ) -> SizedGlyph {
        let variants = horizontalVariants(for: glyph)
        let glyphs = variants.isEmpty ? [glyph] : variants
        var last = SizedGlyph(glyphIDs: [glyphs[0]], ascent: 0, descent: 0, width: 0)
        for g in glyphs {
            let m = measure(glyphs: [g])
            last = SizedGlyph(
                glyphIDs: [g],
                ascent: m.ascent,
                descent: m.descent,
                width: m.width
            )
            if m.width + 0.01 >= width {
                return last
            }
        }
        return last
    }

    /// Horizontal variants first; if still too narrow, MATH `h_assembly` construction.
    func sizedHorizontal(
        _ glyph: CGGlyph,
        coveringWidth width: CGFloat
    ) -> SizedGlyph {
        let variant = findHorizontalVariantSized(glyph, coveringWidth: width)
        if variant.width + 0.1 >= width {
            return variant
        }
        if let assembled = constructHorizontalGlyph(glyph, width: width) {
            return assembled
        }
        // Assembly may be keyed under a variant / PostScript name alias.
        for name in horizontalVariantNames(for: glyph) {
            let id = glyphID(named: name)
            if id != 0, id != glyph, let assembled = constructHorizontalGlyph(id, width: width) {
                return assembled
            }
            if let assembled = constructHorizontalGlyph(named: name, width: width) {
                return assembled
            }
        }
        return variant
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
        return assemblyParts(table.vAssembly[name])
    }

    func horizontalAssembly(for glyph: CGGlyph) -> [GlyphPart] {
        let name = glyphName(for: glyph)
        if let parts = assemblyPartsIfPresent(table.hAssembly[name]), !parts.isEmpty {
            return parts
        }
        // Alias: CT may resolve U+2192 → `arrowright` while assembly is under that name.
        for key in [
            name,
            name + "cmb",
            name.hasSuffix("cmb") ? String(name.dropLast(3)) : name
        ] where !key.isEmpty {
            if let parts = assemblyPartsIfPresent(table.hAssembly[key]), !parts.isEmpty {
                return parts
            }
        }
        return []
    }

    private func assemblyParts(_ assembly: FontTable.Assembly?) -> [GlyphPart] {
        assemblyPartsIfPresent(assembly) ?? []
    }

    private func assemblyPartsIfPresent(_ assembly: FontTable.Assembly?) -> [GlyphPart]? {
        guard let assembly else { return nil }
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
        constructAssembly(
            parts: verticalAssembly(for: glyph),
            target: glyphHeight,
            horizontal: false
        )
    }

    /// Build a stretchy overlay / arrow from `h_assembly` parts when variants are not wide enough.
    func constructHorizontalGlyph(_ glyph: CGGlyph, width targetWidth: CGFloat) -> SizedGlyph? {
        constructAssembly(
            parts: horizontalAssembly(for: glyph),
            target: targetWidth,
            horizontal: true
        )
    }

    /// Assembly looked up by PostScript name (when CT glyph name differs from table key).
    func constructHorizontalGlyph(named name: String, width targetWidth: CGFloat) -> SizedGlyph? {
        guard let assembly = table.hAssembly[name] else { return nil }
        return constructAssembly(
            parts: assemblyParts(assembly),
            target: targetWidth,
            horizontal: true
        )
    }

    /// Shared vertical/horizontal MATH assembly (parts + extenders + connector overlap).
    private func constructAssembly(
        parts: [GlyphPart],
        target: CGFloat,
        horizontal: Bool
    ) -> SizedGlyph? {
        guard !parts.isEmpty else { return nil }

        for numExtenders in 0..<100 {
            var glyphsRv: [CGGlyph] = []
            var offsetsRv: [CGFloat] = []
            /// Joint i (between glyph i and i+1) involves an extender on either side.
            var jointIsExtender: [Bool] = []
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
                        jointIsExtender.append(prev.isExtender || part.isExtender)
                    }
                    offsetsRv.append(minOffset)
                    prev = part
                }
            }

            guard let prev else { continue }
            let minExtent = minOffset + prev.fullAdvance
            let maxExtent = minExtent + maxDelta * CGFloat(max(glyphsRv.count - 1, 0))

            let measured = measure(glyphs: glyphsRv)
            // Cross-axis size: vertical assembly → width from advances; horizontal → height from bounds.
            let crossAscent: CGFloat
            let crossDescent: CGFloat
            let crossWidth: CGFloat
            if horizontal {
                crossAscent = measured.ascent
                crossDescent = measured.descent
                crossWidth = minExtent
            } else {
                crossAscent = minExtent
                crossDescent = 0
                crossWidth = advances(forGlyphs: glyphsRv).map(\.width).max() ?? measured.width
            }

            if minExtent >= target {
                return sizedAssemblyResult(
                    glyphs: glyphsRv,
                    offsets: offsetsRv,
                    ascent: crossAscent,
                    descent: crossDescent,
                    width: horizontal ? minExtent : crossWidth,
                    horizontal: horizontal
                )
            }

            if target <= maxExtent, glyphsRv.count > 1 {
                let delta = target - minExtent
                // Prefer putting stretch into extender joints (HarfBuzz/TeX-like); fall
                // back to all joints when the construction has no extenders.
                let preferred = jointIsExtender.enumerated().compactMap { $0.element ? $0.offset : nil }
                let jointIndices = preferred.isEmpty ? Array(jointIsExtender.indices) : preferred
                let perJoint = delta / CGFloat(max(jointIndices.count, 1))
                var stretchBefore: [CGFloat] = Array(repeating: 0, count: glyphsRv.count)
                var cumulative: CGFloat = 0
                for j in jointIsExtender.indices {
                    if jointIndices.contains(j) {
                        cumulative += perJoint
                    }
                    if j + 1 < stretchBefore.count {
                        stretchBefore[j + 1] = cumulative
                    }
                }
                for i in offsetsRv.indices {
                    offsetsRv[i] += stretchBefore[i]
                }
                let lastOffset = offsetsRv.last ?? 0
                let extent = lastOffset + prev.fullAdvance
                if horizontal {
                    return sizedAssemblyResult(
                        glyphs: glyphsRv,
                        offsets: offsetsRv,
                        ascent: measured.ascent,
                        descent: measured.descent,
                        width: extent,
                        horizontal: true
                    )
                }
                return sizedAssemblyResult(
                    glyphs: glyphsRv,
                    offsets: offsetsRv,
                    ascent: extent,
                    descent: 0,
                    width: crossWidth,
                    horizontal: false
                )
            }
        }
        return nil
    }

    private func sizedAssemblyResult(
        glyphs: [CGGlyph],
        offsets: [CGFloat],
        ascent: CGFloat,
        descent: CGFloat,
        width: CGFloat,
        horizontal: Bool
    ) -> SizedGlyph {
        if horizontal {
            return SizedGlyph(
                glyphIDs: glyphs,
                offsetsY: [],
                offsetsX: offsets,
                ascent: ascent,
                descent: descent,
                width: width
            )
        }
        return SizedGlyph(
            glyphIDs: glyphs,
            offsetsY: offsets,
            offsetsX: [],
            ascent: ascent,
            descent: descent,
            width: width
        )
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

    /// Radical glyph covering `height` (variants, then vertical assembly, then tallest variant).
    func sizedRadical(height: CGFloat) -> SizedGlyph {
        let base = glyph(for: "\u{221A}")
        let variant = findVerticalVariant(base, coveringHeight: height)
        if variant.ascent + variant.descent + 0.1 >= height {
            return variant
        }
        // Prefer assembly keyed by the radical glyph name (`radical` in Latin Modern).
        if let assembled = constructVerticalGlyph(base, height: height) {
            return assembled
        }
        // Some tables store assembly only under the PostScript name `radical`.
        let byName = glyphID(named: "radical")
        if byName != 0, byName != base, let assembled = constructVerticalGlyph(byName, height: height) {
            return assembled
        }
        return variant
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
    /// Fraction of total radical height by which the degree bottom is raised (OpenType).
    var radicalDegreeBottomRaisePercent: CGFloat {
        percentConstant(named: "RadicalDegreeBottomRaisePercent")
    }

    // Limits
    var upperLimitGapMin: CGFloat { constant(named: "UpperLimitGapMin") }
    var lowerLimitGapMin: CGFloat { constant(named: "LowerLimitGapMin") }
    var upperLimitBaselineRiseMin: CGFloat { constant(named: "UpperLimitBaselineRiseMin") }
    var lowerLimitBaselineDropMin: CGFloat { constant(named: "LowerLimitBaselineDropMin") }

    // Axis
    var axisHeight: CGFloat { constant(named: "AxisHeight") }
    /// Estimated axis height fallback when MATH table constants are absent.
    public var estimatedAxisHeight: CGFloat {
        let axis = axisHeight
        return axis > 0 ? axis : font.size * 0.25
    }

    var overbarVerticalGap: CGFloat { constant(named: "OverbarVerticalGap") }
    var overbarRuleThickness: CGFloat { constant(named: "OverbarRuleThickness") }
    var underbarVerticalGap: CGFloat { constant(named: "UnderbarVerticalGap") }
    var underbarRuleThickness: CGFloat { constant(named: "UnderbarRuleThickness") }
    /// TeX ξ₈ — extra descender below the underline rule.
    var underbarExtraDescender: CGFloat { constant(named: "UnderbarExtraDescender") }
}
