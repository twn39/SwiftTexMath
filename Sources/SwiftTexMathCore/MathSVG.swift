@preconcurrency import CoreGraphics
@preconcurrency import CoreText
import Foundation

/// Vector SVG export for laid-out math (glyph outlines + stroked rules).
///
/// Coordinates: math is y-up on the baseline; the root group flips to SVG y-down
/// so outlines from Core Text need no extra scale. Glyphs are emitted as `<path>`
/// via `CTFontCreatePathForGlyph` (no font embedding required).
public enum MathSVG {
    public struct Options: Sendable {
        public var padding: CGFloat
        /// CSS / SVG color for strokes and glyph fills (default black).
        public var foregroundCSS: String
        /// Optional background fill (CSS color). `nil` = transparent.
        public var backgroundCSS: String?
        /// Include `<?xml …?>` declaration (useful for standalone `.svg` files).
        public var includeXMLDeclaration: Bool
        /// Decimal places for path / transform numbers.
        public var precision: Int

        public init(
            padding: CGFloat = 4,
            foregroundCSS: String = "#000000",
            backgroundCSS: String? = nil,
            includeXMLDeclaration: Bool = true,
            precision: Int = 3
        ) {
            self.padding = padding
            self.foregroundCSS = foregroundCSS
            self.backgroundCSS = backgroundCSS
            self.includeXMLDeclaration = includeXMLDeclaration
            self.precision = max(0, min(precision, 8))
        }
    }

    public struct Result: Sendable {
        public var svg: String
        /// Logical size in points (viewBox / width / height).
        public var size: CGSize
        public var display: DisplayList

        public init(svg: String, size: CGSize, display: DisplayList) {
            self.svg = svg
            self.size = size
            self.display = display
        }

        public var data: Data {
            Data(svg.utf8)
        }
    }

    /// Parse + layout + SVG string.
    public static func render(
        latex: String,
        environment: MathEnvironment = MathEnvironment(),
        fonts: any FontProviding = FontRegistry.shared,
        options: Options = Options()
    ) throws -> Result {
        let renderer = MathRenderer(environment: environment, fonts: fonts)
        let display = try renderer.layout(latex: latex)
        return render(display: display, fonts: fonts, options: options)
    }

    /// SVG for an existing display list.
    public static func render(
        display: DisplayList,
        fonts: any FontProviding = FontRegistry.shared,
        options: Options = Options()
    ) -> Result {
        let pad = max(options.padding, 0)
        let width = max(display.width + 2 * pad, 1)
        let height = max(display.ascent + display.descent + 2 * pad, 1)
        let size = CGSize(width: width, height: height)

        var emitter = Emitter(fonts: fonts, options: options)
        // Place baseline at (pad, pad+ascent) then flip y so math y-up matches SVG.
        emitter.openGroup(
            transform:
                "translate(\(fmt(pad, options)) \(fmt(pad + display.ascent, options))) scale(1,-1)"
        )
        emitter.emit(display, origin: .zero, color: options.foregroundCSS)
        emitter.closeGroup()

        var body = ""
        if let bg = options.backgroundCSS {
            body +=
                #"<rect width="\#(fmt(width, options))" height="\#(fmt(height, options))" fill="\#(escapeXML(bg))"/>"#
                + "\n"
        }
        body += emitter.fragments.joined(separator: "\n")

        var svg = ""
        if options.includeXMLDeclaration {
            svg += #"<?xml version="1.0" encoding="UTF-8"?>"# + "\n"
        }
        svg += #"""
        <svg xmlns="http://www.w3.org/2000/svg" width="\#(fmt(width, options))" height="\#(fmt(height, options))" viewBox="0 0 \#(fmt(width, options)) \#(fmt(height, options))">
        \#(body)
        </svg>
        """#

        return Result(svg: svg, size: size, display: display)
    }

    // MARK: - Emitter

    private struct Emitter {
        let fonts: any FontProviding
        let options: Options
        var fragments: [String] = []

        mutating func openGroup(transform: String) {
            fragments.append(#"<g transform="\#(transform)">"#)
        }

        mutating func closeGroup() {
            fragments.append("</g>")
        }

        mutating func emit(_ display: DisplayList, origin: CGPoint, color: String) {
            let ox = origin.x + display.position.x
            let oy = origin.y + display.position.y
            for child in display.children {
                emit(child, origin: CGPoint(x: ox, y: oy), color: color)
            }
        }

        mutating func emit(_ node: DisplayNode, origin: CGPoint, color: String) {
            switch node {
            case .list(let list):
                emit(list, origin: origin, color: color)
            case .glyphs(let run):
                emitGlyphs(run, origin: origin, color: color)
            case .fraction(let fraction):
                emitFraction(fraction, origin: origin, color: color)
            case .radical(let radical):
                emitRadical(radical, origin: origin, color: color)
            case .line(let line):
                emitLine(line, origin: origin, color: color)
            case .largeOperator(let op):
                emitLargeOperator(op, origin: origin, color: color)
            case .colored(let colored):
                emitColored(colored, origin: origin, color: color)
            case .rule(let rule):
                emitRule(rule, origin: origin, color: color)
            case .box(let box):
                emitBox(box, origin: origin, color: color)
            case .stack(let stack):
                emitStack(stack, origin: origin, color: color)
            }
        }

        mutating func emitGlyphs(_ run: GlyphRun, origin: CGPoint, color: String) {
            let base = CGPoint(
                x: origin.x + run.position.x,
                y: origin.y + run.position.y - run.shiftDown
            )
            let ctFont = resolveCTFont(for: run)
            let glyphs = resolveGlyphs(run: run, ctFont: ctFont)
            let positions = glyphPositions(run: run, glyphs: glyphs, ctFont: ctFont)

            for i in glyphs.indices {
                let g = glyphs[i]
                guard g != 0 else { continue }
                let p = positions[i]
                guard let path = CTFontCreatePathForGlyph(ctFont, g, nil) else {
                    // Fallback: single character as text (may miss variants).
                    if i < run.text.utf16.count {
                        let ch = String(run.text.utf16.dropFirst(i).prefix(1).compactMap { UnicodeScalar($0) }.map(Character.init))
                        if !ch.isEmpty {
                            let tx = base.x + p.x
                            let ty = base.y + p.y
                            // Text in flipped space: counter-flip with scale(1,-1).
                            fragments.append(
                                #"<text x="\#(fmt(tx))" y="\#(fmt(ty))" fill="\#(escapeXML(color))" font-size="\#(fmt(run.font.size))" transform="translate(0,\#(fmt(ty))) scale(1,-1) translate(0,\#(fmt(-ty)))" dominant-baseline="alphabetic">\#(escapeXML(ch))</text>"#
                            )
                        }
                    }
                    continue
                }
                let d = cgPathToSVG(path)
                guard !d.isEmpty else { continue }
                let tx = base.x + p.x
                let ty = base.y + p.y
                fragments.append(
                    #"<path transform="translate(\#(fmt(tx)) \#(fmt(ty)))" d="\#(d)" fill="\#(escapeXML(color))"/>"#
                )
            }
        }

        mutating func emitFraction(_ fraction: FractionDisplay, origin: CGPoint, color: String) {
            let ox = origin.x + fraction.position.x
            let oy = origin.y + fraction.position.y
            var num = fraction.numerator
            num.position = CGPoint(x: num.position.x, y: fraction.numeratorOffset)
            emit(num, origin: CGPoint(x: ox, y: oy), color: color)
            var den = fraction.denominator
            den.position = CGPoint(x: den.position.x, y: -fraction.denominatorOffset)
            emit(den, origin: CGPoint(x: ox, y: oy), color: color)
            if fraction.ruleThickness > 0 {
                strokeLine(
                    x1: ox,
                    y1: oy + fraction.ruleOffset,
                    x2: ox + fraction.width,
                    y2: oy + fraction.ruleOffset,
                    thickness: fraction.ruleThickness,
                    color: color
                )
            }
        }

        mutating func emitRadical(_ radical: RadicalDisplay, origin: CGPoint, color: String) {
            let ox = origin.x + radical.position.x
            let oy = origin.y + radical.position.y
            if let degree = radical.degree {
                emit(degree, origin: CGPoint(x: ox, y: oy), color: color)
            }
            emitGlyphs(radical.radicalGlyph, origin: CGPoint(x: ox, y: oy), color: color)
            emit(radical.radicand, origin: CGPoint(x: ox, y: oy), color: color)
            let startX = ox + radical.radicand.position.x
            let barY = oy + radical.ruleOffset
            strokeLine(
                x1: startX,
                y1: barY,
                x2: startX + radical.radicand.width,
                y2: barY,
                thickness: radical.ruleThickness,
                color: color
            )
        }

        mutating func emitLine(_ line: LineDisplay, origin: CGPoint, color: String) {
            let ox = origin.x + line.position.x
            let oy = origin.y + line.position.y
            emit(line.inner, origin: CGPoint(x: ox, y: oy), color: color)
            strokeLine(
                x1: ox,
                y1: oy + line.ruleOffset,
                x2: ox + line.width,
                y2: oy + line.ruleOffset,
                thickness: line.ruleThickness,
                color: color
            )
        }

        mutating func emitLargeOperator(
            _ op: LargeOperatorDisplay,
            origin: CGPoint,
            color: String
        ) {
            let ox = origin.x + op.position.x
            let oy = origin.y + op.position.y
            emitGlyphs(op.nucleus, origin: CGPoint(x: ox, y: oy), color: color)
            if let upper = op.upperLimit {
                emit(upper, origin: CGPoint(x: ox, y: oy), color: color)
            }
            if let lower = op.lowerLimit {
                emit(lower, origin: CGPoint(x: ox, y: oy), color: color)
            }
        }

        mutating func emitColored(_ colored: ColoredDisplay, origin: CGPoint, color: String) {
            let ox = origin.x + colored.position.x
            let oy = origin.y + colored.position.y
            let css = rgbaCSS(
                red: colored.red,
                green: colored.green,
                blue: colored.blue,
                alpha: colored.alpha
            )
            if colored.fillsBackground {
                let x = ox
                let y = oy - colored.descent
                let w = colored.width
                let h = colored.ascent + colored.descent
                fragments.append(
                    #"<rect x="\#(fmt(x))" y="\#(fmt(y))" width="\#(fmt(w))" height="\#(fmt(h))" fill="\#(escapeXML(css))"/>"#
                )
                emit(colored.inner, origin: CGPoint(x: ox, y: oy), color: color)
            } else {
                emit(colored.inner, origin: CGPoint(x: ox, y: oy), color: css)
            }
        }

        mutating func emitRule(_ rule: RuleDisplay, origin: CGPoint, color: String) {
            let ox = origin.x + rule.position.x
            let oy = origin.y + rule.position.y
            if rule.isVertical {
                strokeLine(
                    x1: ox + rule.width / 2,
                    y1: oy + rule.ascent,
                    x2: ox + rule.width / 2,
                    y2: oy - rule.descent,
                    thickness: rule.thickness,
                    color: color
                )
            } else {
                strokeLine(
                    x1: ox,
                    y1: oy,
                    x2: ox + rule.width,
                    y2: oy,
                    thickness: rule.thickness,
                    color: color
                )
            }
        }

        mutating func emitBox(_ box: BoxDisplay, origin: CGPoint, color: String) {
            let ox = origin.x + box.position.x
            let oy = origin.y + box.position.y
            if box.drawChild {
                var child = box.child
                child.position = CGPoint(x: box.childOffsetX, y: 0)
                emit(child, origin: CGPoint(x: ox, y: oy), color: color)
            }
            emitStrike(box: box, origin: CGPoint(x: ox, y: oy), color: color)
        }

        mutating func emitStrike(box: BoxDisplay, origin: CGPoint, color: String) {
            let w = box.width
            let top = box.ascent
            let bot = -box.descent
            let t = box.strikeThickness
            switch box.strike {
            case .none:
                return
            case .forward:
                strokeLine(x1: origin.x, y1: origin.y + bot, x2: origin.x + w, y2: origin.y + top, thickness: t, color: color)
            case .backward:
                strokeLine(x1: origin.x, y1: origin.y + top, x2: origin.x + w, y2: origin.y + bot, thickness: t, color: color)
            case .cross:
                strokeLine(x1: origin.x, y1: origin.y + bot, x2: origin.x + w, y2: origin.y + top, thickness: t, color: color)
                strokeLine(x1: origin.x, y1: origin.y + top, x2: origin.x + w, y2: origin.y + bot, thickness: t, color: color)
            case .horizontal:
                let y = origin.y + box.strikeVerticalOffset
                strokeLine(x1: origin.x, y1: y, x2: origin.x + w, y2: y, thickness: t, color: color)
            case .frame:
                let pad = t * 2
                let x = origin.x - pad
                let y = origin.y + bot - pad
                let rw = w + 2 * pad
                let rh = top - bot + 2 * pad
                fragments.append(
                    #"<rect x="\#(fmt(x))" y="\#(fmt(y))" width="\#(fmt(rw))" height="\#(fmt(rh))" fill="none" stroke="\#(escapeXML(color))" stroke-width="\#(fmt(t))"/>"#
                )
            }
        }

        mutating func emitStack(_ stack: StackDisplay, origin: CGPoint, color: String) {
            let ox = origin.x + stack.position.x
            let oy = origin.y + stack.position.y
            emit(stack.base, origin: CGPoint(x: ox, y: oy), color: color)
            if let over = stack.over {
                emit(over, origin: CGPoint(x: ox, y: oy), color: color)
            }
            if let under = stack.under {
                emit(under, origin: CGPoint(x: ox, y: oy), color: color)
            }
        }

        mutating func strokeLine(
            x1: CGFloat,
            y1: CGFloat,
            x2: CGFloat,
            y2: CGFloat,
            thickness: CGFloat,
            color: String
        ) {
            fragments.append(
                #"<line x1="\#(fmt(x1))" y1="\#(fmt(y1))" x2="\#(fmt(x2))" y2="\#(fmt(y2))" stroke="\#(escapeXML(color))" stroke-width="\#(fmt(thickness))" stroke-linecap="butt"/>"#
            )
        }

        func resolveCTFont(for run: GlyphRun) -> CTFont {
            if let name = run.fallbackFontName {
                return CTFontCreateWithName(name as CFString, run.font.size, nil)
            }
            if run.usesSystemFallback {
                return CTFontCreateUIFontForLanguage(.system, run.font.size, nil)
                    ?? CTFontCreateWithName("Helvetica" as CFString, run.font.size, nil)
            }
            if let metrics = fonts.metrics(for: run.font) {
                return metrics.ctFont
            }
            return CTFontCreateWithName("Helvetica" as CFString, run.font.size, nil)
        }

        func resolveGlyphs(run: GlyphRun, ctFont: CTFont) -> [CGGlyph] {
            if !run.glyphIDs.isEmpty, !run.usesSystemFallback, run.fallbackFontName == nil {
                return run.glyphIDs.map { CGGlyph($0) }
            }
            var chars = Array(run.text.utf16)
            var resolved = [CGGlyph](repeating: 0, count: chars.count)
            CTFontGetGlyphsForCharacters(ctFont, &chars, &resolved, chars.count)
            return resolved
        }

        func glyphPositions(run: GlyphRun, glyphs: [CGGlyph], ctFont: CTFont) -> [CGPoint] {
            var positions = [CGPoint](repeating: .zero, count: glyphs.count)
            if !run.glyphOffsetsY.isEmpty, run.glyphOffsetsY.count == glyphs.count {
                for i in glyphs.indices {
                    positions[i] = CGPoint(x: 0, y: run.glyphOffsetsY[i])
                }
            } else if !run.glyphOffsetsX.isEmpty, run.glyphOffsetsX.count == glyphs.count {
                for i in glyphs.indices {
                    positions[i] = CGPoint(x: run.glyphOffsetsX[i], y: 0)
                }
            } else {
                var advances = [CGSize](repeating: .zero, count: glyphs.count)
                CTFontGetAdvancesForGlyphs(ctFont, .horizontal, glyphs, &advances, glyphs.count)
                var x: CGFloat = 0
                for i in glyphs.indices {
                    positions[i] = CGPoint(x: x, y: 0)
                    x += advances[i].width
                }
            }
            return positions
        }

        func fmt(_ value: CGFloat) -> String {
            MathSVG.fmt(value, options)
        }

        func cgPathToSVG(_ path: CGPath) -> String {
            MathSVG.cgPathToSVG(path, precision: options.precision)
        }
    }

    // MARK: - Formatting helpers

    private static func fmt(_ value: CGFloat, _ options: Options) -> String {
        fmt(value, precision: options.precision)
    }

    private static func fmt(_ value: CGFloat, precision: Int) -> String {
        if value == 0 { return "0" }
        let absVal = abs(value)
        if absVal >= 1000 || (absVal < 0.001 && absVal > 0) {
            return String(format: "%.\(precision)g", Double(value))
        }
        var s = String(format: "%.\(precision)f", Double(value))
        // Trim trailing zeros
        while s.contains("."), s.hasSuffix("0") {
            s.removeLast()
        }
        if s.hasSuffix(".") { s.removeLast() }
        if s == "-0" { return "0" }
        return s
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func rgbaCSS(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> String {
        let r = Int((red * 255).rounded().clamped(to: 0...255))
        let g = Int((green * 255).rounded().clamped(to: 0...255))
        let b = Int((blue * 255).rounded().clamped(to: 0...255))
        if alpha >= 0.999 {
            return String(format: "#%02x%02x%02x", r, g, b)
        }
        return String(format: "rgba(%d,%d,%d,%.3f)", r, g, b, Double(alpha))
    }

    private static func cgPathToSVG(_ path: CGPath, precision: Int) -> String {
        var d = ""
        path.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                let p = points[0]
                d += "M\(fmt(p.x, precision: precision)) \(fmt(p.y, precision: precision))"
            case .addLineToPoint:
                let p = points[0]
                d += "L\(fmt(p.x, precision: precision)) \(fmt(p.y, precision: precision))"
            case .addQuadCurveToPoint:
                let c = points[0]
                let p = points[1]
                d +=
                    "Q\(fmt(c.x, precision: precision)) \(fmt(c.y, precision: precision)) \(fmt(p.x, precision: precision)) \(fmt(p.y, precision: precision))"
            case .addCurveToPoint:
                let c1 = points[0]
                let c2 = points[1]
                let p = points[2]
                d +=
                    "C\(fmt(c1.x, precision: precision)) \(fmt(c1.y, precision: precision)) \(fmt(c2.x, precision: precision)) \(fmt(c2.y, precision: precision)) \(fmt(p.x, precision: precision)) \(fmt(p.y, precision: precision))"
            case .closeSubpath:
                d += "Z"
            @unknown default:
                break
            }
        }
        return d
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
