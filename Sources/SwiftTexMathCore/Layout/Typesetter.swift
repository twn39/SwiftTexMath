import CoreGraphics
import Foundation

/// TeX Appendix G typesetter (normalize-then-single-pass layout).
public enum Typesetter {
    public static func createDisplay(
        for list: MathList,
        environment: MathEnvironment
    ) -> DisplayList {
        let normalized = MathNormalizer.normalize(list)
        guard let metrics = FontRegistry.shared.metrics(for: environment.font) else {
            return DisplayList()
        }
        return typeset(normalized, env: environment, metrics: metrics)
    }

    static func typeset(
        _ list: MathList,
        env: MathEnvironment,
        metrics: FontMetrics
    ) -> DisplayList {
        if env.maxWidth > 0 {
            return typesetWrapped(list, env: env, metrics: metrics)
        }
        return typesetSingleLine(list, env: env, metrics: metrics)
    }

    // MARK: - Single line

    private static func typesetSingleLine(
        _ list: MathList,
        env: MathEnvironment,
        metrics: FontMetrics
    ) -> DisplayList {
        var env = env
        var children: [DisplayNode] = []
        var x: CGFloat = 0
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var prevKind: AtomKind?

        let styleFont = MathFont(name: env.font.name, size: env.styleFontSize)
        let styleMetrics = FontRegistry.shared.metrics(for: styleFont) ?? metrics

        for atom in list.atoms {
            if case .style(let style) = atom.payload {
                env.style = style
                continue
            }
            if case .space(let mu) = atom.payload {
                x += mu * styleMetrics.mathUnit
                prevKind = .ordinary
                continue
            }
            // `\middle` boundaries only belong inside `\left...\right`.
            if atom.kind == .boundary {
                continue
            }

            if let prev = prevKind {
                x += InterElementSpacing.space(
                    left: prev,
                    right: atom.kind,
                    style: env.style,
                    parameters: env.parameters,
                    mathUnit: styleMetrics.mathUnit
                )
            }

            let node = makeNode(for: atom, ctx: LayoutContext(env: env, metrics: styleMetrics))
            var placed = node
            placed.position = CGPoint(x: x, y: 0)
            children.append(placed)
            x += placed.width
            ascent = max(ascent, placed.ascent)
            descent = max(descent, placed.descent)
            prevKind = atom.kind
        }

        return DisplayList(ascent: ascent, descent: descent, width: x, children: children)
    }

    // MARK: - maxWidth wrapping

    private struct PlacedAtom {
        var atom: MathAtom
        var node: DisplayNode
        var spacingBefore: CGFloat
    }

    private static func typesetWrapped(
        _ list: MathList,
        env: MathEnvironment,
        metrics: FontMetrics
    ) -> DisplayList {
        let maxWidth = env.maxWidth
        let styleFont = MathFont(name: env.font.name, size: env.styleFontSize)
        let styleMetrics = FontRegistry.shared.metrics(for: styleFont) ?? metrics

        var env = env
        var items: [PlacedAtom] = []
        var prevKind: AtomKind?

        for atom in list.atoms {
            if case .style(let style) = atom.payload {
                env.style = style
                continue
            }
            if case .space(let mu) = atom.payload {
                let width = mu * styleMetrics.mathUnit
                items.append(
                    PlacedAtom(
                        atom: atom,
                        node: .glyphs(
                            GlyphRun(
                                text: "",
                                font: styleFont,
                                ascent: 0,
                                descent: 0,
                                width: width
                            )
                        ),
                        spacingBefore: 0
                    )
                )
                prevKind = .ordinary
                continue
            }
            if atom.kind == .boundary { continue }

            let spacing: CGFloat
            if let prev = prevKind {
                spacing = InterElementSpacing.space(
                    left: prev,
                    right: atom.kind,
                    style: env.style,
                    parameters: env.parameters,
                    mathUnit: styleMetrics.mathUnit
                )
            } else {
                spacing = 0
            }

            // Nested content uses remaining width when breaking.
            var childEnv = env
            childEnv.maxWidth = max(0, maxWidth)
            let node = makeNode(
                for: atom,
                ctx: LayoutContext(env: childEnv, metrics: styleMetrics)
            )
            items.append(PlacedAtom(atom: atom, node: node, spacingBefore: spacing))
            prevKind = atom.kind
        }

        guard !items.isEmpty else { return DisplayList() }

        var lines: [[PlacedAtom]] = [[]]
        var lineWidth: CGFloat = 0

        for (index, item) in items.enumerated() {
            let add = (lines[lines.count - 1].isEmpty ? 0 : item.spacingBefore) + item.node.width
            let wouldExceed = !lines[lines.count - 1].isEmpty && lineWidth + add > maxWidth

            if wouldExceed, canBreakBefore(item.atom, previous: lines[lines.count - 1].last?.atom) {
                lines.append([item])
                lineWidth = item.node.width
                continue
            }

            if wouldExceed, let breakAt = bestBreakIndex(in: lines[lines.count - 1]) {
                let moved = Array(lines[lines.count - 1][breakAt...])
                lines[lines.count - 1] = Array(lines[lines.count - 1][..<breakAt])
                lines.append(moved)
                lineWidth = lineWidthOf(moved)
                let addAfterBreak =
                    (lines[lines.count - 1].isEmpty ? 0 : item.spacingBefore) + item.node.width
                if lineWidth + addAfterBreak > maxWidth, canBreakBefore(item.atom, previous: moved.last?.atom) {
                    lines.append([item])
                    lineWidth = item.node.width
                } else {
                    lines[lines.count - 1].append(item)
                    lineWidth += addAfterBreak
                }
                continue
            }

            lines[lines.count - 1].append(item)
            lineWidth += add
            _ = index
        }

        let lineGap = styleMetrics.mathUnit * 2
        var lineDisplays: [DisplayList] = []
        var totalAscent: CGFloat = 0
        var totalDescent: CGFloat = 0
        var totalWidth: CGFloat = 0
        var y: CGFloat = 0

        for (lineIndex, line) in lines.enumerated() {
            let display = materializeLine(line)
            totalWidth = max(totalWidth, display.width)
            if lineIndex == 0 {
                totalAscent = display.ascent
                totalDescent = display.descent
                y = 0
            } else {
                let step = lineDisplays[lineIndex - 1].descent + lineGap + display.ascent
                y -= step
                totalDescent = -y + display.descent
            }
            var placed = display
            placed.position = CGPoint(x: 0, y: y)
            lineDisplays.append(placed)
        }

        let children = lineDisplays.map { DisplayNode.list($0) }
        return DisplayList(
            ascent: totalAscent,
            descent: totalDescent,
            width: min(totalWidth, maxWidth),
            children: children
        )
    }

    private static func materializeLine(_ items: [PlacedAtom]) -> DisplayList {
        var children: [DisplayNode] = []
        var x: CGFloat = 0
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        for (i, item) in items.enumerated() {
            if i > 0 { x += item.spacingBefore }
            var node = item.node
            node.position = CGPoint(x: x, y: 0)
            children.append(node)
            x += node.width
            ascent = max(ascent, node.ascent)
            descent = max(descent, node.descent)
        }
        return DisplayList(ascent: ascent, descent: descent, width: x, children: children)
    }

    private static func lineWidthOf(_ items: [PlacedAtom]) -> CGFloat {
        var w: CGFloat = 0
        for (i, item) in items.enumerated() {
            if i > 0 { w += item.spacingBefore }
            w += item.node.width
        }
        return w
    }

    /// Prefer breaks before relations / binary ops / after spaces; avoid mid-word and before punctuation.
    private static func canBreakBefore(_ atom: MathAtom, previous: MathAtom?) -> Bool {
        // Never break before trailing punctuation (keep "word," together).
        if atom.kind == .punctuation { return false }

        if let previous {
            if previous.kind == .open { return false }
            // Space is an explicit break opportunity (common inside `\text{…}`).
            if case .space = previous.payload { return true }
            // Don't split a multi-letter text word across letters.
            if isTextLetter(previous), isTextLetter(atom) { return false }
        }

        switch atom.kind {
        case .relation, .binaryOperator:
            return true
        case .space:
            return true
        default:
            return previous?.kind == .relation
                || previous?.kind == .binaryOperator
                || previous?.kind == .punctuation
                || previous?.kind == .close
                || (previous.map { if case .space = $0.payload { return true }; return false } ?? false)
        }
    }

    private static func isTextLetter(_ atom: MathAtom) -> Bool {
        guard atom.kind == .ordinary || atom.kind == .variable || atom.kind == .number else {
            return false
        }
        guard atom.nucleus.count == 1, let ch = atom.nucleus.first else { return false }
        return ch.isLetter || ch.isNumber
    }

    private static func bestBreakIndex(in line: [PlacedAtom]) -> Int? {
        guard line.count > 1 else { return nil }
        for i in stride(from: line.count - 1, through: 1, by: -1) {
            if canBreakBefore(line[i].atom, previous: line[i - 1].atom) {
                return i
            }
        }
        return nil
    }

    // MARK: - Nodes

    private static func makeNode(for atom: MathAtom, ctx: LayoutContext) -> DisplayNode {
        let env = ctx.env
        let metrics = ctx.metrics
        let typesetChild = ctx.childTypesetter()

        let useLimits =
            atom.kind == .largeOperator && atom.limits && env.style == .display

        let base: DisplayNode
        switch atom.payload {
        case .fraction(let fraction):
            base = FractionLayout.make(fraction, env: env, metrics: metrics, typeset: typesetChild)
        case .radical(let radical):
            base = RadicalLayout.make(radical, env: env, metrics: metrics, typeset: typesetChild)
        case .inner(let inner):
            base = DelimiterLayout.makeInner(inner, env: env, metrics: metrics, typeset: typesetChild)
        case .largeOperator where useLimits:
            return LargeOperatorLayout.make(
                atom: atom,
                env: env,
                metrics: metrics,
                typeset: typesetChild
            )
        case .largeOperator:
            base = glyphNode(for: atom, env: env, metrics: metrics, enlarge: env.style == .display)
        case .overline(let list):
            base = LineLayout.makeOverline(list, env: env, metrics: metrics, typeset: typesetChild)
        case .underline(let list):
            base = LineLayout.makeUnderline(list, env: env, metrics: metrics, typeset: typesetChild)
        case .accent(let accent):
            base = AccentLayout.make(accent, env: env, metrics: metrics, typeset: typesetChild)
        case .table(let table):
            base = TableLayout.make(table, env: env, metrics: metrics, typeset: typesetChild)
        case .styled(let styled):
            base = .list(typesetChild(styled.contents, env.with(variant: styled.variant)))
        case .colored(let colored):
            let inner = typesetChild(colored.contents, env)
            if let comps = MathColor.components(from: colored.color) {
                base = .colored(
                    ColoredDisplay(
                        inner: inner,
                        red: comps.red,
                        green: comps.green,
                        blue: comps.blue,
                        alpha: comps.alpha
                    )
                )
            } else {
                base = .list(inner)
            }
        case .mathChoice(let choice):
            base = .list(typesetChild(choice.list(for: env.style), env))
        case .box(let box):
            base = BoxLayout.make(box, env: env, metrics: metrics, typeset: typesetChild)
        case .stack(let stack):
            base = StackLayout.make(stack, env: env, metrics: metrics, typeset: typesetChild)
        case .none, .space, .style:
            base = glyphNode(for: atom, env: env, metrics: metrics, enlarge: false)
        }

        return ScriptLayout.attach(
            base: base,
            superscript: atom.superscript,
            subscript: atom.subscript,
            env: env,
            metrics: metrics,
            typeset: typesetChild
        )
    }

    private static func glyphNode(
        for atom: MathAtom,
        env: MathEnvironment,
        metrics: FontMetrics,
        enlarge: Bool
    ) -> DisplayNode {
        let styleFont = MathFont(name: env.font.name, size: env.styleFontSize)
        let styleMetrics = FontRegistry.shared.metrics(for: styleFont) ?? metrics
        let text = mapNucleus(atom.nucleus, variant: env.variant, kind: atom.kind)
        var glyphID = styleMetrics.glyph(for: text.isEmpty ? " " : text)
        if enlarge {
            glyphID = styleMetrics.largerGlyph(glyphID, forDisplayStyle: true)
        }
        let measured = styleMetrics.measure(glyphs: [glyphID])
        let italic = styleMetrics.italicCorrection(for: glyphID)
        return .glyphs(
            GlyphRun(
                text: text,
                font: styleFont,
                ascent: measured.ascent,
                descent: measured.descent,
                width: text.isEmpty ? 0 : measured.width,
                glyphIDs: text.isEmpty ? [] : [UInt16(glyphID)],
                italicCorrection: italic
            )
        )
    }

    private static func mapNucleus(_ nucleus: String, variant: MathVariant, kind: AtomKind) -> String {
        // Allow multi-char mapping for blackboard digits etc. by mapping char-wise.
        if nucleus.count != 1 {
            return String(nucleus.map { mapCharacter($0, variant: variant, kind: kind) })
        }
        guard let ch = nucleus.first else { return nucleus }
        return String(mapCharacter(ch, variant: variant, kind: kind))
    }

    private static func mapCharacter(_ ch: Character, variant: MathVariant, kind: AtomKind) -> Character {
        let isLetter = ("a"..."z").contains(ch) || ("A"..."Z").contains(ch)
        let isDigit = ("0"..."9").contains(ch)

        switch variant {
        case .upright:
            return ch
        case .bold:
            guard isLetter else { return ch }
            return mathBold(ch)
        case .italic:
            if kind == .largeOperator { return ch }
            guard isLetter else { return ch }
            return mathItalic(ch)
        case .caligraphic, .script:
            guard isLetter else { return ch }
            return mathScript(ch)
        case .fraktur:
            guard isLetter else { return ch }
            return mathFraktur(ch)
        case .blackboard:
            if isLetter || isDigit { return mathBlackboard(ch) }
            return ch
        case .boldItalic:
            guard isLetter else { return ch }
            return mathBoldItalic(ch)
        case .sans:
            guard isLetter || isDigit else { return ch }
            return mathSans(ch)
        case .typewriter:
            guard isLetter || isDigit else { return ch }
            return mathTypewriter(ch)
        }
    }

    private static func mathBoldItalic(_ ch: Character) -> Character {
        guard let scalar = ch.unicodeScalars.first else { return ch }
        let v = scalar.value
        if (65...90).contains(v) {
            return Character(UnicodeScalar(0x1D468 + (v - 65))!)
        }
        if (97...122).contains(v) {
            return Character(UnicodeScalar(0x1D482 + (v - 97))!)
        }
        return ch
    }

    private static func mathSans(_ ch: Character) -> Character {
        guard let scalar = ch.unicodeScalars.first else { return ch }
        let v = scalar.value
        if (65...90).contains(v) {
            return Character(UnicodeScalar(0x1D5A0 + (v - 65))!)
        }
        if (97...122).contains(v) {
            return Character(UnicodeScalar(0x1D5BA + (v - 97))!)
        }
        if (48...57).contains(v) {
            return Character(UnicodeScalar(0x1D7E2 + (v - 48))!)
        }
        return ch
    }

    private static func mathTypewriter(_ ch: Character) -> Character {
        guard let scalar = ch.unicodeScalars.first else { return ch }
        let v = scalar.value
        if (65...90).contains(v) {
            return Character(UnicodeScalar(0x1D670 + (v - 65))!)
        }
        if (97...122).contains(v) {
            return Character(UnicodeScalar(0x1D68A + (v - 97))!)
        }
        if (48...57).contains(v) {
            return Character(UnicodeScalar(0x1D7F6 + (v - 48))!)
        }
        return ch
    }

    private static func mathItalic(_ ch: Character) -> Character {
        guard let scalar = ch.unicodeScalars.first else { return ch }
        let v = scalar.value
        if (65...90).contains(v) {
            return Character(UnicodeScalar(0x1D434 + (v - 65))!)
        }
        if (97...122).contains(v) {
            if ch == "h" { return "\u{210E}" }
            return Character(UnicodeScalar(0x1D44E + (v - 97))!)
        }
        return ch
    }

    private static func mathBold(_ ch: Character) -> Character {
        guard let scalar = ch.unicodeScalars.first else { return ch }
        let v = scalar.value
        if (65...90).contains(v) {
            return Character(UnicodeScalar(0x1D400 + (v - 65))!)
        }
        if (97...122).contains(v) {
            return Character(UnicodeScalar(0x1D41A + (v - 97))!)
        }
        return ch
    }

    /// Unicode Mathematical Script (plus letterlike exceptions used by fonts).
    private static func mathScript(_ ch: Character) -> Character {
        switch ch {
        case "B": return "\u{212C}"
        case "E": return "\u{2130}"
        case "F": return "\u{2131}"
        case "H": return "\u{210B}"
        case "I": return "\u{2110}"
        case "L": return "\u{2112}"
        case "M": return "\u{2133}"
        case "R": return "\u{211B}"
        case "e": return "\u{212F}"
        case "g": return "\u{210A}"
        case "o": return "\u{2134}"
        default:
            guard let scalar = ch.unicodeScalars.first else { return ch }
            let v = scalar.value
            if (65...90).contains(v) {
                return Character(UnicodeScalar(0x1D49C + (v - 65))!)
            }
            if (97...122).contains(v) {
                // LM Math lacks lower script; keep upright letter rather than tofu.
                return ch
            }
            return ch
        }
    }

    private static func mathFraktur(_ ch: Character) -> Character {
        switch ch {
        case "C": return "\u{212D}"
        case "H": return "\u{210C}"
        case "I": return "\u{2111}"
        case "R": return "\u{211C}"
        case "Z": return "\u{2128}"
        default:
            guard let scalar = ch.unicodeScalars.first else { return ch }
            let v = scalar.value
            if (65...90).contains(v) {
                return Character(UnicodeScalar(0x1D504 + (v - 65))!)
            }
            if (97...122).contains(v) {
                return Character(UnicodeScalar(0x1D51E + (v - 97))!)
            }
            return ch
        }
    }

    private static func mathBlackboard(_ ch: Character) -> Character {
        switch ch {
        case "C": return "\u{2102}"
        case "H": return "\u{210D}"
        case "N": return "\u{2115}"
        case "P": return "\u{2119}"
        case "Q": return "\u{211A}"
        case "R": return "\u{211D}"
        case "Z": return "\u{2124}"
        default:
            guard let scalar = ch.unicodeScalars.first else { return ch }
            let v = scalar.value
            if (65...90).contains(v) {
                return Character(UnicodeScalar(0x1D538 + (v - 65))!)
            }
            if (97...122).contains(v) {
                return Character(UnicodeScalar(0x1D552 + (v - 97))!)
            }
            if (48...57).contains(v) {
                return Character(UnicodeScalar(0x1D7D8 + (v - 48))!)
            }
            return ch
        }
    }
}
