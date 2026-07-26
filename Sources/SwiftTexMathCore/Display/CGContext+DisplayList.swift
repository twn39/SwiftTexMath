@preconcurrency import CoreGraphics
@preconcurrency import CoreText
import Foundation

extension CGContext {
    /// Draws a display list with the given foreground color (math y-up coordinates).
    public func draw(
        _ display: DisplayList,
        at origin: CGPoint,
        foregroundColor: CGColor,
        fonts: any FontProviding = FontRegistry.shared
    ) {
        saveGState()
        translateBy(x: origin.x, y: origin.y)
        draw(display, foregroundColor: foregroundColor, fonts: fonts)
        restoreGState()
    }

    public func draw(
        _ display: DisplayList,
        foregroundColor: CGColor,
        fonts: any FontProviding = FontRegistry.shared
    ) {
        saveGState()
        translateBy(x: display.position.x, y: display.position.y)
        for child in display.children {
            draw(child, foregroundColor: foregroundColor, fonts: fonts)
        }
        restoreGState()
    }

    public func draw(
        _ node: DisplayNode,
        foregroundColor: CGColor,
        fonts: any FontProviding = FontRegistry.shared
    ) {
        var visitor = CGContextDrawingVisitor(context: self, foregroundColor: foregroundColor, fonts: fonts)
        node.accept(&visitor)
    }

private struct CGContextDrawingVisitor: DisplayNodeVisitor {
    let context: CGContext
    let foregroundColor: CGColor
    let fonts: any FontProviding

    mutating func visit(list: DisplayList) {
        context.draw(list, foregroundColor: foregroundColor, fonts: fonts)
    }

    mutating func visit(glyphs: GlyphRun) {
        context.draw(glyphs, foregroundColor: foregroundColor, fonts: fonts)
    }

    mutating func visit(fraction: FractionDisplay) {
        context.draw(fraction, foregroundColor: foregroundColor, fonts: fonts)
    }

    mutating func visit(radical: RadicalDisplay) {
        context.draw(radical, foregroundColor: foregroundColor, fonts: fonts)
    }

    mutating func visit(line: LineDisplay) {
        context.draw(line, foregroundColor: foregroundColor, fonts: fonts)
    }

    mutating func visit(largeOperator: LargeOperatorDisplay) {
        context.draw(largeOperator, foregroundColor: foregroundColor, fonts: fonts)
    }

    mutating func visit(colored: ColoredDisplay) {
        context.draw(colored, foregroundColor: foregroundColor, fonts: fonts)
    }

    mutating func visit(rule: RuleDisplay) {
        context.draw(rule, foregroundColor: foregroundColor)
    }

    mutating func visit(box: BoxDisplay) {
        context.draw(box, foregroundColor: foregroundColor, fonts: fonts)
    }

    mutating func visit(stack: StackDisplay) {
        context.draw(stack, foregroundColor: foregroundColor, fonts: fonts)
    }
}

    private func draw(
        _ box: BoxDisplay,
        foregroundColor: CGColor,
        fonts: any FontProviding
    ) {
        saveGState()
        translateBy(x: box.position.x, y: box.position.y)
        if box.drawChild {
            var child = box.child
            child.position = CGPoint(x: box.childOffsetX, y: 0)
            draw(child, foregroundColor: foregroundColor, fonts: fonts)
        }
        drawStrike(for: box, foregroundColor: foregroundColor)
        restoreGState()
    }

    private func drawStrike(for box: BoxDisplay, foregroundColor: CGColor) {
        let segments: [(CGPoint, CGPoint)]
        let w = box.width
        let top = box.ascent
        let bot = -box.descent
        switch box.strike {
        case .none:
            return
        case .forward:
            segments = [(CGPoint(x: 0, y: bot), CGPoint(x: w, y: top))]
        case .backward:
            segments = [(CGPoint(x: 0, y: top), CGPoint(x: w, y: bot))]
        case .cross:
            segments = [
                (CGPoint(x: 0, y: bot), CGPoint(x: w, y: top)),
                (CGPoint(x: 0, y: top), CGPoint(x: w, y: bot))
            ]
        case .horizontal:
            let y = box.strikeVerticalOffset
            segments = [(CGPoint(x: 0, y: y), CGPoint(x: w, y: y))]
        case .frame:
            let pad = box.strikeThickness * 2
            let rect = CGRect(
                x: -pad,
                y: bot - pad,
                width: w + 2 * pad,
                height: top - bot + 2 * pad
            )
            setStrokeColor(foregroundColor)
            setLineWidth(box.strikeThickness)
            stroke(rect)
            return
        }
        setStrokeColor(foregroundColor)
        setLineWidth(box.strikeThickness)
        for (a, b) in segments {
            move(to: a)
            addLine(to: b)
        }
        strokePath()
    }

    private func draw(
        _ stack: StackDisplay,
        foregroundColor: CGColor,
        fonts: any FontProviding
    ) {
        saveGState()
        translateBy(x: stack.position.x, y: stack.position.y)
        draw(stack.base, foregroundColor: foregroundColor, fonts: fonts)
        if let over = stack.over {
            draw(over, foregroundColor: foregroundColor, fonts: fonts)
        }
        if let under = stack.under {
            draw(under, foregroundColor: foregroundColor, fonts: fonts)
        }
        restoreGState()
    }

    private func draw(
        _ colored: ColoredDisplay,
        foregroundColor: CGColor,
        fonts: any FontProviding
    ) {
        saveGState()
        translateBy(x: colored.position.x, y: colored.position.y)
        if colored.fillsBackground {
            let rect = CGRect(
                x: 0,
                y: -colored.descent,
                width: colored.width,
                height: colored.ascent + colored.descent
            )
            setFillColor(colored.cgColor)
            fill(rect)
            draw(colored.inner, foregroundColor: foregroundColor, fonts: fonts)
        } else {
            draw(colored.inner, foregroundColor: colored.cgColor, fonts: fonts)
        }
        restoreGState()
    }

    private func draw(_ rule: RuleDisplay, foregroundColor: CGColor) {
        saveGState()
        translateBy(x: rule.position.x, y: rule.position.y)
        setStrokeColor(foregroundColor)
        setLineWidth(rule.thickness)
        if rule.isVertical {
            move(to: CGPoint(x: rule.width / 2, y: rule.ascent))
            addLine(to: CGPoint(x: rule.width / 2, y: -rule.descent))
        } else {
            move(to: CGPoint(x: 0, y: 0))
            addLine(to: CGPoint(x: rule.width, y: 0))
        }
        strokePath()
        restoreGState()
    }

    private func draw(
        _ run: GlyphRun,
        foregroundColor: CGColor,
        fonts: any FontProviding
    ) {
        let ctFont: CTFont
        if let name = run.fallbackFontName {
            ctFont = CTFontCreateWithName(name as CFString, run.font.size, nil)
        } else if run.usesSystemFallback {
            ctFont = CTFontCreateUIFontForLanguage(.system, run.font.size, nil)
                ?? CTFontCreateWithName("Helvetica" as CFString, run.font.size, nil)
        } else {
            guard let metrics = fonts.metrics(for: run.font) else { return }
            ctFont = metrics.ctFont
        }

        saveGState()
        translateBy(x: run.position.x, y: run.position.y - run.shiftDown)
        setFillColor(foregroundColor)

        let glyphs: [CGGlyph]
        if !run.glyphIDs.isEmpty, !run.usesSystemFallback, run.fallbackFontName == nil {
            glyphs = run.glyphIDs.map { CGGlyph($0) }
        } else {
            var chars = Array(run.text.utf16)
            var resolved = [CGGlyph](repeating: 0, count: chars.count)
            CTFontGetGlyphsForCharacters(ctFont, &chars, &resolved, chars.count)
            glyphs = resolved
        }

        var positions = [CGPoint](repeating: .zero, count: glyphs.count)
        if !run.glyphOffsetsY.isEmpty, run.glyphOffsetsY.count == glyphs.count {
            // Vertical MATH assembly: stack parts on the y axis.
            for i in glyphs.indices {
                positions[i] = CGPoint(x: 0, y: run.glyphOffsetsY[i])
            }
        } else if !run.glyphOffsetsX.isEmpty, run.glyphOffsetsX.count == glyphs.count {
            // Horizontal MATH assembly: place parts along x with connector overlaps.
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
        CTFontDrawGlyphs(ctFont, glyphs, positions, glyphs.count, self)
        restoreGState()
    }

    private func draw(
        _ fraction: FractionDisplay,
        foregroundColor: CGColor,
        fonts: any FontProviding
    ) {
        saveGState()
        translateBy(x: fraction.position.x, y: fraction.position.y)

        // Offsets are baseline-relative; the bar sits on the math axis (`ruleOffset`).
        var num = fraction.numerator
        num.position = CGPoint(x: num.position.x, y: fraction.numeratorOffset)
        draw(num, foregroundColor: foregroundColor, fonts: fonts)

        var den = fraction.denominator
        den.position = CGPoint(x: den.position.x, y: -fraction.denominatorOffset)
        draw(den, foregroundColor: foregroundColor, fonts: fonts)

        if fraction.ruleThickness > 0 {
            setStrokeColor(foregroundColor)
            setLineWidth(fraction.ruleThickness)
            let y = fraction.ruleOffset
            move(to: CGPoint(x: 0, y: y))
            addLine(to: CGPoint(x: fraction.width, y: y))
            strokePath()
        }

        restoreGState()
    }

    private func draw(
        _ radical: RadicalDisplay,
        foregroundColor: CGColor,
        fonts: any FontProviding
    ) {
        saveGState()
        translateBy(x: radical.position.x, y: radical.position.y)

        if let degree = radical.degree {
            draw(degree, foregroundColor: foregroundColor, fonts: fonts)
        }
        draw(radical.radicalGlyph, foregroundColor: foregroundColor, fonts: fonts)
        draw(radical.radicand, foregroundColor: foregroundColor, fonts: fonts)

        // Overbar (center at ruleOffset so gap above radicand is preserved)
        setStrokeColor(foregroundColor)
        setLineWidth(radical.ruleThickness)
        let startX = radical.radicand.position.x
        let barY = radical.ruleOffset
        move(to: CGPoint(x: startX, y: barY))
        addLine(to: CGPoint(x: startX + radical.radicand.width, y: barY))
        strokePath()

        restoreGState()
    }

    private func draw(
        _ line: LineDisplay,
        foregroundColor: CGColor,
        fonts: any FontProviding
    ) {
        saveGState()
        translateBy(x: line.position.x, y: line.position.y)
        draw(line.inner, foregroundColor: foregroundColor, fonts: fonts)
        setStrokeColor(foregroundColor)
        setLineWidth(line.ruleThickness)
        let y = line.ruleOffset
        move(to: CGPoint(x: 0, y: y))
        addLine(to: CGPoint(x: line.width, y: y))
        strokePath()
        restoreGState()
    }

    private func draw(
        _ op: LargeOperatorDisplay,
        foregroundColor: CGColor,
        fonts: any FontProviding
    ) {
        saveGState()
        translateBy(x: op.position.x, y: op.position.y)
        draw(op.nucleus, foregroundColor: foregroundColor, fonts: fonts)
        if let upper = op.upperLimit {
            draw(upper, foregroundColor: foregroundColor, fonts: fonts)
        }
        if let lower = op.lowerLimit {
            draw(lower, foregroundColor: foregroundColor, fonts: fonts)
        }
        restoreGState()
    }
}
