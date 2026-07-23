import CoreGraphics
import Foundation

enum AccentLayout {
    static func make(
        _ accent: MathAtom.Accent,
        env: MathEnvironment,
        metrics: FontMetrics,
        fonts: any FontProviding = FontRegistry.shared,
        typeset: (MathList, MathEnvironment) -> DisplayList
    ) -> DisplayNode {
        // General mark list (`\underaccent{\ast}{x}`) — script-sized decoration.
        if let mark = accent.mark, !mark.atoms.isEmpty {
            return makeMarkListAccent(
                mark: mark,
                base: accent.base,
                isBelow: accent.isBelow,
                env: env,
                metrics: metrics,
                typeset: typeset
            )
        }

        let cramped = !accent.isBelow
        let innerBase = typeset(accent.base, env.with(cramped: cramped))
        let styleFont = MathFont(name: env.font.name, size: env.styleFontSize)
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics

        let baseGlyphID = styleMetrics.glyph(for: accent.accent)
        let resolvedBase = resolveAccentGlyph(
            baseGlyphID,
            accent: accent,
            metrics: styleMetrics
        )
        let sizedAccent: SizedGlyph
        if accent.stretchable {
            sizedAccent = styleMetrics.sizedHorizontal(
                resolvedBase,
                coveringWidth: innerBase.width
            )
        } else {
            let flattened = pickFlattenedAccentIfNeeded(
                resolvedBase,
                baseAscent: innerBase.ascent,
                metrics: styleMetrics
            )
            let measured = styleMetrics.measure(glyphs: [flattened])
            sizedAccent = SizedGlyph(
                glyphIDs: [flattened],
                ascent: measured.ascent,
                descent: measured.descent,
                width: measured.width
            )
        }
        let accentGlyphID = sizedAccent.glyphIDs.last ?? resolvedBase
        let accentWidth = sizedAccent.width
        let accentAscent = sizedAccent.ascent
        let accentDescent = sizedAccent.descent

        // Attachment / italic come from the last glyph (OpenType accent attach point).
        // Multi-letter bases: full last-glyph italic over-shifts a short mark on a wide
        // word; blend toward centering (still keep last-glyph attachment for single letters).
        let lastItalic = italicCorrection(of: .list(innerBase))
        let multiLetterBase = isMultiLetterBase(.list(innerBase), atomCount: accent.base.atoms.count)
        let italic: CGFloat
        if multiLetterBase, !accent.isBelow, !accent.stretchable {
            italic = lastItalic * 0.5
        } else {
            italic = lastItalic
        }
        let baseAdjust = accentAttachment(
            of: .list(innerBase),
            metrics: styleMetrics,
            accent: accent
        )
        // Signed MATH attachment X (combining marks may be negative). Align attachment
        // points: baseAttach − accentAttach; below accents still use the same table.
        let accentAdjust = styleMetrics.accentAttachmentX(for: accentGlyphID)
        var skew = italic + (baseAdjust - accentAdjust)
        if accent.isBelow {
            // Under-accents: italic correction is usually less relevant; prefer centering
            // when the base is wider than the mark or when stretching.
            if accent.stretchable || innerBase.width > accentWidth + styleMetrics.mathUnit {
                skew = (innerBase.width - accentWidth) / 2
            } else {
                // Keep attachment alignment but drop italic for below marks.
                skew = baseAdjust - accentAdjust
            }
        } else if accent.stretchable, innerBase.width > styleMetrics.mathUnit * 4 {
            skew = (innerBase.width - accentWidth) / 2 + lastItalic * 0.5
        } else if multiLetterBase, !accent.stretchable,
                  innerBase.width > accentWidth + styleMetrics.mathUnit * 2 {
            // Short non-stretch mark on a multi-letter base: blend attachment skew with center.
            let centered = (innerBase.width - accentWidth) / 2
            skew = skew * 0.35 + centered * 0.65
        }

        let accentY: CGFloat
        let ascent: CGFloat
        let descent: CGFloat
        if accent.isBelow {
            // Vertical: underbar gap (OpenType has no separate bottom vertical attach).
            // Horizontal attach already applied via `skew` / `accentAttachmentX`.
            let gap = styleMetrics.underbarVerticalGap
            accentY = -(innerBase.descent + gap + max(accentAscent, 0))
            ascent = innerBase.ascent
            descent = max(innerBase.descent, -accentY + accentDescent)
        } else {
            // OpenType: when base exceeds AccentBaseHeight, sit the accent on top
            // (attachment depth capped). Tall bases above FlattenedAccentBaseHeight
            // already use a flatter glyph when available (`pickFlattenedAccentIfNeeded`).
            let cap = styleMetrics.accentBaseHeight
            let delta = min(innerBase.ascent, cap)
            accentY = max(innerBase.ascent - delta, 0)
            ascent = max(innerBase.ascent, accentY + accentAscent)
            descent = innerBase.descent
        }

        let left = min(0, skew)
        let right = max(innerBase.width, skew + accentWidth)
        let totalWidth = right - left

        var placedBase = innerBase
        placedBase.position = CGPoint(x: -left, y: 0)
        let accentGlyph = GlyphRun(
            text: accent.accent,
            font: styleFont,
            ascent: accentAscent,
            descent: accentDescent,
            width: accentWidth,
            position: CGPoint(x: skew - left, y: accentY),
            glyphIDs: sizedAccent.glyphIDs.map { UInt16($0) },
            glyphOffsetsY: sizedAccent.offsetsY,
            glyphOffsetsX: sizedAccent.offsetsX,
            italicCorrection: styleMetrics.italicCorrection(for: accentGlyphID)
        )

        return .list(
            DisplayList(
                ascent: ascent,
                descent: descent,
                width: totalWidth,
                children: [.list(placedBase), .glyphs(accentGlyph)]
            )
        )
    }

    /// When the base is taller than `FlattenedAccentBaseHeight`, prefer a lower-profile
    /// accent glyph if the font exposes one via a `flat` / `flattened` name or a
    /// shorter horizontal-variant entry.
    private static func pickFlattenedAccentIfNeeded(
        _ glyph: CGGlyph,
        baseAscent: CGFloat,
        metrics: FontMetrics
    ) -> CGGlyph {
        guard baseAscent > metrics.flattenedAccentBaseHeight + 0.01 else {
            return glyph
        }
        let name = metrics.glyphName(for: glyph)
        let flatCandidates = [
            name + "flat",
            name + ".flat",
            name + "flattened",
            "flat" + name
        ]
        for key in flatCandidates {
            let id = metrics.glyphID(named: key)
            if id != 0 { return id }
        }
        // Prefer the lowest-profile glyph among early horizontal variants when present.
        let variants = metrics.horizontalVariants(for: glyph)
        if variants.count > 1 {
            var best = glyph
            let baseM = metrics.measure(glyphs: [glyph])
            var bestHeight = baseM.ascent + baseM.descent
            for g in variants.prefix(3) {
                let m = metrics.measure(glyphs: [g])
                let h = m.ascent + m.descent
                if h + 0.01 < bestHeight {
                    best = g
                    bestHeight = h
                }
            }
            return best
        }
        return glyph
    }

    /// Script-sized free-form mark above/below the base (accents package).
    private static func makeMarkListAccent(
        mark: MathList,
        base: MathList,
        isBelow: Bool,
        env: MathEnvironment,
        metrics: FontMetrics,
        typeset: (MathList, MathEnvironment) -> DisplayList
    ) -> DisplayNode {
        let baseEnv = env.with(cramped: !isBelow)
        let markEnv = env.with(style: env.style.scriptStyle, cramped: isBelow)
        var innerBase = typeset(base, baseEnv)
        var markDisplay = typeset(mark, markEnv)

        let gap = isBelow ? metrics.underbarVerticalGap : metrics.overbarVerticalGap
        let width = max(innerBase.width, markDisplay.width)
        innerBase.position = CGPoint(x: (width - innerBase.width) / 2, y: 0)

        let accentY: CGFloat
        let ascent: CGFloat
        let descent: CGFloat
        if isBelow {
            accentY = -(innerBase.descent + gap + markDisplay.ascent)
            markDisplay.position = CGPoint(x: (width - markDisplay.width) / 2, y: accentY)
            ascent = innerBase.ascent
            descent = max(innerBase.descent, -accentY + markDisplay.descent)
        } else {
            accentY = innerBase.ascent + gap + markDisplay.descent
            markDisplay.position = CGPoint(x: (width - markDisplay.width) / 2, y: accentY)
            ascent = max(innerBase.ascent, accentY + markDisplay.ascent)
            descent = innerBase.descent
        }

        return .list(
            DisplayList(
                ascent: ascent,
                descent: descent,
                width: width,
                children: [.list(innerBase), .list(markDisplay)]
            )
        )
    }

    /// Map plain combining accents to `*belowcmb` / `*cmb` glyph names when present.
    private static func resolveAccentGlyph(
        _ glyph: CGGlyph,
        accent: MathAtom.Accent,
        metrics: FontMetrics
    ) -> CGGlyph {
        let name = metrics.glyphName(for: glyph)
        if accent.isBelow {
            // `\underaccent{\tilde}` / utilde → prefer dedicated below combining forms.
            var candidates = [
                name + "belowcmb",
                name.replacingOccurrences(of: "cmb", with: "belowcmb"),
                name.replacingOccurrences(of: "comb", with: "belowcmb"),
                "tildebelowcmb",
                "uni0330", // combining tilde below
                name
            ]
            // Unicode combining tilde (U+0303) often maps to tildecomb / tilde.
            if accent.accent == "\u{0303}" || accent.accent == "\u{0330}" {
                candidates.insert(contentsOf: ["tildebelowcmb", "uni0330", "tildecomb"], at: 0)
            }
            for key in candidates {
                let id = metrics.glyphID(named: key)
                if id != 0 { return id }
            }
        }
        if accent.stretchable {
            let cmb = metrics.glyphID(named: name + "cmb")
            if cmb != 0 { return cmb }
            let comb = metrics.glyphID(named: name + "comb")
            if comb != 0 { return comb }
        }
        return glyph == 0 ? metrics.glyph(for: accent.accent) : glyph
    }

    private static func accentAttachment(
        of node: DisplayNode,
        metrics: FontMetrics,
        accent: MathAtom.Accent
    ) -> CGFloat {
        switch node {
        case .glyphs(let run):
            if let last = run.glyphIDs.last {
                return metrics.accentAttachmentX(for: CGGlyph(last))
            }
        case .list(let list):
            if let last = list.children.last {
                return accentAttachment(of: last, metrics: metrics, accent: accent)
            }
        default:
            break
        }
        if let lastAtomNucleus = accent.base.atoms.last?.nucleus, !lastAtomNucleus.isEmpty {
            return metrics.accentAttachmentX(for: metrics.glyph(for: lastAtomNucleus))
        }
        if case .list(let list) = node {
            return list.width / 2
        }
        return node.width / 2
    }

    private static func italicCorrection(of node: DisplayNode) -> CGFloat {
        switch node {
        case .glyphs(let run):
            return run.italicCorrection
        case .list(let list):
            return list.children.last.map(italicCorrection(of:)) ?? 0
        default:
            return 0
        }
    }

    /// True when the accent base is wider than a single ordinary letter (glyph count or atom count).
    private static func isMultiLetterBase(_ node: DisplayNode, atomCount: Int) -> Bool {
        if atomCount > 1 { return true }
        return glyphCount(of: node) > 1
    }

    private static func glyphCount(of node: DisplayNode) -> Int {
        switch node {
        case .glyphs(let run):
            return max(run.glyphIDs.count, run.text.unicodeScalars.count)
        case .list(let list):
            return list.children.reduce(0) { $0 + glyphCount(of: $1) }
        case .fraction, .radical, .largeOperator, .line, .colored, .box, .stack, .rule:
            // Compound bases (e.g. `\hat{\frac{a}{b}}`) are not multi-letter words.
            return 1
        }
    }
}
