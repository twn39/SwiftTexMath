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
        createDisplayResult(for: list, environment: environment, fonts: fonts).display
    }

    /// Layout plus the resolved `\label` → bare marker map used by `\ref` / `\eqref`.
    public static func createDisplayResult(
        for list: MathList,
        environment: MathEnvironment,
        fonts: any FontProviding = FontRegistry.shared
    ) -> (display: DisplayList, labels: EquationLabelMap) {
        let normalized = MathNormalizer.normalize(list)
        let labelMap = EquationLabelMap()
        EquationNumbering.collect(normalized, env: environment, map: labelMap)
        guard let metrics = fonts.metrics(for: environment.font) else {
            return (DisplayList(), labelMap)
        }
        // Always allocate a counter so outer envs (`equation`, `align`, …) can number
        // without requiring `numberEquations` for free-standing lines.
        let counter = EquationCounter(start: environment.equationNumberStart)
        let display = typeset(
            normalized,
            env: environment,
            metrics: metrics,
            fonts: fonts,
            equationCounter: counter,
            labelMap: labelMap
        )
        return (display, labelMap)
    }

    static func typeset(
        _ list: MathList,
        env: MathEnvironment,
        metrics: FontMetrics,
        fonts: any FontProviding = FontRegistry.shared,
        depth: Int = 0,
        equationCounter: EquationCounter? = nil,
        labelMap: EquationLabelMap? = nil
    ) -> DisplayList {
        if depth > env.maxRecursionDepth {
            return DisplayList()
        }
        if env.maxWidth > 0 {
            return WrapLayout.typeset(
                list,
                env: env,
                metrics: metrics,
                fonts: fonts,
                equationCounter: equationCounter,
                labelMap: labelMap,
                makeNode: { atom, ctx in makeNode(for: atom, ctx: ctx) }
            )
        }
        return typesetSingleLine(
            list,
            env: env,
            metrics: metrics,
            fonts: fonts,
            depth: depth,
            equationCounter: equationCounter,
            labelMap: labelMap
        )
    }

    // MARK: - Single line

    private static func typesetSingleLine(
        _ list: MathList,
        env: MathEnvironment,
        metrics: FontMetrics,
        fonts: any FontProviding,
        depth: Int = 0,
        equationCounter: EquationCounter? = nil,
        labelMap: EquationLabelMap? = nil
    ) -> DisplayList {
        var env = env
        var children: [DisplayNode] = []
        var x: CGFloat = 0
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var prevKind: AtomKind?
        /// Last `\tag` / `\tag*` on the line (amsmath: one label, flush-right when width known).
        var pendingTag: DisplayNode?
        var pendingTagBare: String?
        var suppressNumbering = false
        var lineLabels: [String] = []

        let styleFont = MathFont(
            name: env.font.name,
            size: metrics.styleFontSize(baseSize: env.font.size, style: env.style)
        )
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics
        let layoutCtx = { (e: MathEnvironment) in
            LayoutContext(
                env: e,
                metrics: styleMetrics,
                fonts: fonts,
                depth: depth,
                equationCounter: equationCounter,
                labelMap: labelMap
            )
        }

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

            // Tags are not inter-element atoms; place after body (flush-right if maxWidth).
            if case .tag(let tag) = atom.payload {
                if tag.suppress {
                    suppressNumbering = true
                    pendingTag = nil
                    pendingTagBare = nil
                } else {
                    suppressNumbering = false
                    pendingTag = makeNode(for: atom, ctx: layoutCtx(env))
                    pendingTagBare = EquationNumbering.flattenList(tag.contents)
                }
                continue
            }
            // `\label{…}` is layout-neutral.
            if case .label(let name) = atom.payload {
                lineLabels.append(name)
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

            let node = makeNode(for: atom, ctx: layoutCtx(env))
            var placed = node
            placed.position = CGPoint(x: x, y: 0)
            children.append(placed)
            x += placed.width
            ascent = max(ascent, placed.ascent)
            descent = max(descent, placed.descent)
            prevKind = atom.kind
        }

        // Auto `(n)` when enabled, display style, content present, no \tag/\notag.
        if pendingTag == nil,
           !suppressNumbering,
           env.numberEquations,
           env.style == .display,
           !children.isEmpty,
           let counter = equationCounter {
            let n = counter.take()
            pendingTagBare = String(n)
            let auto = MathAtom.Tag(
                contents: numberList(n),
                parenthesize: true
            )
            pendingTag = .list(
                makeTagDisplay(auto, env: env, typeset: layoutCtx(env).childTypesetter())
            )
        }

        // Keep label map in sync with the line's visible marker (pre-pass already filled it).
        if !suppressNumbering, let bare = pendingTagBare, !bare.isEmpty, let labelMap {
            for name in lineLabels {
                labelMap.bind(name, to: bare)
            }
        }

        if var tag = pendingTag {
            let gap = styleMetrics.mathUnit * 18 // 1em thick-ish gap when flowing inline
            let tagX: CGFloat
            if env.maxWidth > 0 {
                tagX = max(x + gap, env.maxWidth - tag.width)
            } else {
                tagX = x + gap
            }
            tag.position = CGPoint(x: tagX, y: 0)
            children.append(tag)
            x = max(x, tagX + tag.width)
            if env.maxWidth > 0 {
                x = max(x, env.maxWidth)
            }
            ascent = max(ascent, tag.ascent)
            descent = max(descent, tag.descent)
        }

        return DisplayList(ascent: ascent, descent: descent, width: x, children: children)
    }

    /// Digits for auto equation numbers as ordinary atoms.
    static func numberList(_ value: Int) -> MathList {
        var list = MathList()
        for ch in String(value) {
            list.append(MathAtom.ordinary(String(ch)))
        }
        return list
    }

    /// Outer amsmath-like envs that receive equation numbers (not inner `aligned` / `gathered` / `split`).
    static func tableEnvironmentAutoNumbers(_ name: String) -> Bool {
        switch name {
        case "align", "gather", "eqnarray", "equation", "multline":
            return true
        default:
            return false
        }
    }

    /// Envs that number even when ``MathEnvironment/numberEquations`` is false (TeX default for outer displays).
    static func tableEnvironmentForcesNumbering(_ name: String) -> Bool {
        tableEnvironmentAutoNumbers(name)
    }

    /// Scan a table row's cells for explicit `\tag` / `\notag` (last wins).
    static func rowTagPolicy(cells: [MathList]) -> (suppress: Bool, explicitTag: MathAtom.Tag?) {
        var suppress = false
        var explicit: MathAtom.Tag?
        for cell in cells {
            for atom in cell.atoms {
                if case .tag(let tag) = atom.payload {
                    if tag.suppress {
                        suppress = true
                        explicit = nil
                    } else {
                        suppress = false
                        explicit = tag
                    }
                }
            }
        }
        return (suppress, explicit)
    }

    /// Drop top-level `\tag` / `\notag` atoms so multi-line envs can place labels at row end.
    static func strippingTags(from list: MathList) -> MathList {
        MathList(atoms: list.atoms.filter { atom in
            switch atom.payload {
            case .tag, .label:
                return false
            default:
                return true
            }
        })
    }

    /// Collect `\label{…}` names on a table row (top-level cells only).
    static func rowLabelNames(cells: [MathList]) -> [String] {
        var names: [String] = []
        for cell in cells {
            for atom in cell.atoms {
                if case .label(let name) = atom.payload {
                    names.append(name)
                }
            }
        }
        return names
    }

    /// Whether a multi-line / equation-like table should hoist tags to the row margin.
    static func tableEnvironmentHoistsTags(_ name: String) -> Bool {
        if tableEnvironmentAutoNumbers(name) { return true }
        switch name {
        case "aligned", "gathered", "split", "alignedat", "alignat",
             "flalign", "flalign*", "align*", "gather*", "multline*", "equation*":
            return true
        default:
            return false
        }
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
                table,
                env: env,
                metrics: metrics,
                fonts: fonts,
                typeset: typesetChild,
                equationCounter: ctx.equationCounter,
                labelMap: ctx.labelMap
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
        case .tag(let tag):
            if tag.suppress {
                base = .list(DisplayList())
            } else {
                base = .list(makeTagDisplay(tag, env: env, typeset: typesetChild))
            }
        case .label:
            return .list(DisplayList())
        case .ref(let name, let parenthesize):
            let text = ctx.labelMap?.displayText(for: name, parenthesize: parenthesize)
                ?? (parenthesize ? "(??)" : "??")
            base = .list(makeUprightText(text, env: env, typeset: typesetChild))
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
        let styleFont = MathFont(name: env.font.name, size: metrics.styleFontSize(baseSize: env.font.size, style: env.style))
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics
        let text = MathVariantMapper.mapNucleus(atom.nucleus, variant: env.variant, kind: atom.kind)
        let measureText = text.isEmpty ? " " : text
        var glyphIDs = styleMetrics.glyphs(for: measureText)

        // Missing glyph in math font → text fallback (CJK / emoji / rare chars).
        if (glyphIDs.first ?? 0) == 0, !text.isEmpty {
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

        if enlarge, glyphIDs.count == 1 {
            glyphIDs = [styleMetrics.largerGlyph(glyphIDs.first ?? 0, forDisplayStyle: true)]
        }
        let measured = styleMetrics.measure(glyphs: glyphIDs)
        let italic = glyphIDs.count == 1 ? styleMetrics.italicCorrection(for: glyphIDs.first ?? 0) : 0
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
                glyphIDs: text.isEmpty ? [] : glyphIDs.map { UInt16($0) },
                shiftDown: shift,
                italicCorrection: italic
            )
        )
    }

    /// Upright tag body, optionally parenthesized (`\tag` vs `\tag*`).
    static func makeTagDisplay(
        _ tag: MathAtom.Tag,
        env: MathEnvironment,
        typeset: (MathList, MathEnvironment) -> DisplayList
    ) -> DisplayList {
        if tag.suppress {
            return DisplayList()
        }
        var body = MathList()
        if tag.parenthesize {
            body.append(MathAtom.ordinary("("))
        }
        for atom in tag.contents.atoms {
            body.append(atom)
        }
        if tag.parenthesize {
            body.append(MathAtom.ordinary(")"))
        }
        // Never auto-number inside a tag body (would recurse infinitely).
        var tagEnv = env.with(variant: .upright)
        tagEnv.numberEquations = false
        tagEnv.maxWidth = 0
        return typeset(body, tagEnv)
    }

    /// Upright text run for resolved `\ref` / `\eqref` markers.
    static func makeUprightText(
        _ text: String,
        env: MathEnvironment,
        typeset: (MathList, MathEnvironment) -> DisplayList
    ) -> DisplayList {
        var body = MathList()
        for ch in text {
            body.append(MathAtom.ordinary(String(ch)))
        }
        var textEnv = env.with(variant: .upright)
        textEnv.numberEquations = false
        textEnv.maxWidth = 0
        return typeset(body, textEnv)
    }

    private static func fallbackCTFont(named name: String?, size: CGFloat) -> CTFont {
        if let name {
            return CTFontCreateWithName(name as CFString, size, nil)
        }
        return CTFontCreateUIFontForLanguage(.system, size, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
    }
}
