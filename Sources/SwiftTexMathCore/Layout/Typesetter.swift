import CoreGraphics
import CoreText
import Foundation

/// TeX Appendix G typesetter (normalize-then-single-pass layout).
public enum Typesetter {
    public static func createDisplay(
        for list: MathList,
        environment: MathEnvironment,
        fonts: any FontProviding = FontRegistry.shared
    ) -> DisplayList {
        let normalized = MathNormalizer.normalize(list)
        guard let metrics = fonts.metrics(for: environment.font) else {
            return DisplayList()
        }
        return typeset(normalized, env: environment, metrics: metrics, fonts: fonts)
    }

    static func typeset(
        _ list: MathList,
        env: MathEnvironment,
        metrics: FontMetrics,
        fonts: any FontProviding = FontRegistry.shared
    ) -> DisplayList {
        if env.maxWidth > 0 {
            return WrapLayout.typeset(
                list,
                env: env,
                metrics: metrics,
                fonts: fonts,
                makeNode: { atom, ctx in makeNode(for: atom, ctx: ctx) }
            )
        }
        return typesetSingleLine(list, env: env, metrics: metrics, fonts: fonts)
    }

    // MARK: - Single line

    private static func typesetSingleLine(
        _ list: MathList,
        env: MathEnvironment,
        metrics: FontMetrics,
        fonts: any FontProviding
    ) -> DisplayList {
        var env = env
        var children: [DisplayNode] = []
        var x: CGFloat = 0
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var prevKind: AtomKind?

        let styleFont = MathFont(name: env.font.name, size: env.styleFontSize)
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics

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
            // Defense in depth: Normalize drops bare boundaries; keep skip for safety.
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

            let node = makeNode(
                for: atom,
                ctx: LayoutContext(env: env, metrics: styleMetrics, fonts: fonts)
            )
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

    // MARK: - Nodes

    private static func makeNode(for atom: MathAtom, ctx: LayoutContext) -> DisplayNode {
        let env = ctx.env
        let metrics = ctx.metrics
        let fonts = ctx.fonts
        let typesetChild = ctx.childTypesetter()

        let useLimits =
            atom.kind == .largeOperator && atom.limits && env.style == .display

        let base: DisplayNode
        switch atom.payload {
        case .fraction(let fraction):
            base = FractionLayout.make(fraction, env: env, metrics: metrics, typeset: typesetChild)
        case .radical(let radical):
            base = RadicalLayout.make(
                radical, env: env, metrics: metrics, fonts: fonts, typeset: typesetChild
            )
        case .inner(let inner):
            base = DelimiterLayout.makeInner(
                inner, env: env, metrics: metrics, fonts: fonts, typeset: typesetChild
            )
        case .largeOperator where useLimits:
            return LargeOperatorLayout.make(
                atom: atom,
                env: env,
                metrics: metrics,
                fonts: fonts,
                typeset: typesetChild
            )
        case .largeOperator:
            // Side-script path (`\int_0^1`, text-style `\sum_i`): still center on axis.
            base = glyphNode(
                for: atom,
                env: env,
                metrics: metrics,
                fonts: fonts,
                enlarge: env.style == .display,
                centerOnAxis: true
            )
        case .overline(let list):
            base = LineLayout.makeOverline(list, env: env, metrics: metrics, typeset: typesetChild)
        case .underline(let list):
            base = LineLayout.makeUnderline(list, env: env, metrics: metrics, typeset: typesetChild)
        case .accent(let accent):
            base = AccentLayout.make(
                accent, env: env, metrics: metrics, fonts: fonts, typeset: typesetChild
            )
        case .table(let table):
            base = TableLayout.make(
                table, env: env, metrics: metrics, fonts: fonts, typeset: typesetChild
            )
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
                        alpha: comps.alpha,
                        fillsBackground: colored.fillsBackground
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
            base = StackLayout.make(
                stack, env: env, metrics: metrics, fonts: fonts, typeset: typesetChild
            )
        case .none, .space, .style:
            base = glyphNode(
                for: atom, env: env, metrics: metrics, fonts: fonts, enlarge: false, centerOnAxis: false
            )
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
        fonts: any FontProviding,
        enlarge: Bool,
        centerOnAxis: Bool
    ) -> DisplayNode {
        let styleFont = MathFont(name: env.font.name, size: env.styleFontSize)
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics
        let text = MathVariantMapper.mapNucleus(atom.nucleus, variant: env.variant, kind: atom.kind)
        let measureText = text.isEmpty ? " " : text
        var glyphID = styleMetrics.glyph(for: measureText)

        // Missing glyph in math font → text fallback (CJK / emoji / rare chars).
        if glyphID == 0, !text.isEmpty {
            let fallback = fallbackCTFont(named: env.textFallbackFontName, size: styleFont.size)
            let attributed = NSAttributedString(
                string: text,
                attributes: [NSAttributedString.Key(kCTFontAttributeName as String): fallback]
            )
            let line = CTLineCreateWithAttributedString(attributed)
            let bounds = CTLineGetBoundsWithOptions(line, [])
            let width = CTLineGetTypographicBounds(line, nil, nil, nil)
            return .glyphs(
                GlyphRun(
                    text: text,
                    font: styleFont,
                    ascent: max(bounds.maxY, 0),
                    descent: max(-bounds.minY, 0),
                    width: width > 0 ? width : bounds.width,
                    glyphIDs: [],
                    fallbackFontName: env.textFallbackFontName,
                    usesSystemFallback: env.textFallbackFontName == nil
                )
            )
        }

        if enlarge {
            glyphID = styleMetrics.largerGlyph(glyphID, forDisplayStyle: true)
        }
        let measured = styleMetrics.measure(glyphs: [glyphID])
        let italic = styleMetrics.italicCorrection(for: glyphID)
        let shift: CGFloat
        if centerOnAxis {
            shift = 0.5 * (measured.ascent - measured.descent) - styleMetrics.axisHeight
        } else {
            shift = 0
        }
        return .glyphs(
            GlyphRun(
                text: text,
                font: styleFont,
                ascent: measured.ascent,
                descent: measured.descent,
                width: text.isEmpty ? 0 : measured.width,
                glyphIDs: text.isEmpty ? [] : [UInt16(glyphID)],
                shiftDown: shift,
                italicCorrection: italic
            )
        )
    }

    private static func fallbackCTFont(named name: String?, size: CGFloat) -> CTFont {
        if let name {
            return CTFontCreateWithName(name as CFString, size, nil)
        }
        return CTFontCreateUIFontForLanguage(.system, size, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
    }
}
