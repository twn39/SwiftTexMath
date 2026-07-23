@preconcurrency import CoreGraphics
@preconcurrency import CoreText
import Foundation

extension CGContext {
    /// Draws a display list with the given foreground color (math y-up coordinates).
    public func draw(_ display: DisplayList, at origin: CGPoint, foregroundColor: CGColor) {
        saveGState()
        translateBy(x: origin.x, y: origin.y)
        draw(display, foregroundColor: foregroundColor)
        restoreGState()
    }

    public func draw(_ display: DisplayList, foregroundColor: CGColor) {
        saveGState()
        translateBy(x: display.position.x, y: display.position.y)
        for child in display.children {
            draw(child, foregroundColor: foregroundColor)
        }
        restoreGState()
    }

    public func draw(_ node: DisplayNode, foregroundColor: CGColor) {
        switch node {
        case .list(let list):
            draw(list, foregroundColor: foregroundColor)
        case .glyphs(let run):
            draw(run, foregroundColor: foregroundColor)
        case .fraction(let fraction):
            draw(fraction, foregroundColor: foregroundColor)
        case .radical(let radical):
            draw(radical, foregroundColor: foregroundColor)
        case .line(let line):
            draw(line, foregroundColor: foregroundColor)
        case .largeOperator(let op):
            draw(op, foregroundColor: foregroundColor)
        case .colored(let colored):
            draw(colored)
        case .rule(let rule):
            draw(rule, foregroundColor: foregroundColor)
        case .box(let box):
            draw(box, foregroundColor: foregroundColor)
        case .stack(let stack):
            draw(stack, foregroundColor: foregroundColor)
        }
    }

    private func draw(_ box: BoxDisplay, foregroundColor: CGColor) {
        saveGState()
        translateBy(x: box.position.x, y: box.position.y)
        if box.drawChild {
            var child = box.child
            child.position = CGPoint(x: box.childOffsetX, y: 0)
            draw(child, foregroundColor: foregroundColor)
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
                (CGPoint(x: 0, y: top), CGPoint(x: w, y: bot)),
            ]
        case .horizontal:
            let y = box.strikeVerticalOffset
            segments = [(CGPoint(x: 0, y: y), CGPoint(x: w, y: y))]
        }
        setStrokeColor(foregroundColor)
        setLineWidth(box.strikeThickness)
        for (a, b) in segments {
            move(to: a)
            addLine(to: b)
        }
        strokePath()
    }

    private func draw(_ stack: StackDisplay, foregroundColor: CGColor) {
        saveGState()
        translateBy(x: stack.position.x, y: stack.position.y)
        draw(stack.base, foregroundColor: foregroundColor)
        if let over = stack.over {
            draw(over, foregroundColor: foregroundColor)
        }
        if let under = stack.under {
            draw(under, foregroundColor: foregroundColor)
        }
        restoreGState()
    }

    private func draw(_ colored: ColoredDisplay) {
        saveGState()
        translateBy(x: colored.position.x, y: colored.position.y)
        draw(colored.inner, foregroundColor: colored.cgColor)
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

    private func draw(_ run: GlyphRun, foregroundColor: CGColor) {
        guard let metrics = FontRegistry.shared.metrics(for: run.font) else { return }
        saveGState()
        translateBy(x: run.position.x, y: run.position.y - run.shiftDown)
        setFillColor(foregroundColor)

        let glyphs: [CGGlyph]
        if !run.glyphIDs.isEmpty {
            glyphs = run.glyphIDs.map { CGGlyph($0) }
        } else {
            var chars = Array(run.text.utf16)
            var resolved = [CGGlyph](repeating: 0, count: chars.count)
            CTFontGetGlyphsForCharacters(metrics.ctFont, &chars, &resolved, chars.count)
            glyphs = resolved
        }

        var positions = [CGPoint](repeating: .zero, count: glyphs.count)
        if !run.glyphOffsetsY.isEmpty, run.glyphOffsetsY.count == glyphs.count {
            // Vertical assembly: stack parts at x = 0 with MATH-table offsets.
            for i in glyphs.indices {
                positions[i] = CGPoint(x: 0, y: run.glyphOffsetsY[i])
            }
        } else {
            var advances = [CGSize](repeating: .zero, count: glyphs.count)
            CTFontGetAdvancesForGlyphs(metrics.ctFont, .horizontal, glyphs, &advances, glyphs.count)
            var x: CGFloat = 0
            for i in glyphs.indices {
                positions[i] = CGPoint(x: x, y: 0)
                x += advances[i].width
            }
        }
        CTFontDrawGlyphs(metrics.ctFont, glyphs, positions, glyphs.count, self)
        restoreGState()
    }

    private func draw(_ fraction: FractionDisplay, foregroundColor: CGColor) {
        saveGState()
        translateBy(x: fraction.position.x, y: fraction.position.y)

        var num = fraction.numerator
        num.position = CGPoint(x: num.position.x, y: fraction.numeratorOffset)
        draw(num, foregroundColor: foregroundColor)

        var den = fraction.denominator
        den.position = CGPoint(x: den.position.x, y: -fraction.denominatorOffset)
        draw(den, foregroundColor: foregroundColor)

        if fraction.ruleThickness > 0 {
            setStrokeColor(foregroundColor)
            setLineWidth(fraction.ruleThickness)
            move(to: CGPoint(x: 0, y: 0))
            addLine(to: CGPoint(x: fraction.width, y: 0))
            strokePath()
        }

        restoreGState()
    }

    private func draw(_ radical: RadicalDisplay, foregroundColor: CGColor) {
        saveGState()
        translateBy(x: radical.position.x, y: radical.position.y)

        if let degree = radical.degree {
            draw(degree, foregroundColor: foregroundColor)
        }
        draw(radical.radicalGlyph, foregroundColor: foregroundColor)
        draw(radical.radicand, foregroundColor: foregroundColor)

        // Overbar
        let barY = radical.radicand.ascent + radical.ruleThickness
        setStrokeColor(foregroundColor)
        setLineWidth(radical.ruleThickness)
        let startX = radical.radicand.position.x
        move(to: CGPoint(x: startX, y: barY))
        addLine(to: CGPoint(x: startX + radical.radicand.width, y: barY))
        strokePath()

        restoreGState()
    }

    private func draw(_ line: LineDisplay, foregroundColor: CGColor) {
        saveGState()
        translateBy(x: line.position.x, y: line.position.y)
        draw(line.inner, foregroundColor: foregroundColor)
        setStrokeColor(foregroundColor)
        setLineWidth(line.ruleThickness)
        if line.isOverline {
            let y = line.inner.ascent + line.ruleThickness
            move(to: CGPoint(x: 0, y: y))
            addLine(to: CGPoint(x: line.width, y: y))
        } else {
            let y = -(line.inner.descent + line.ruleThickness)
            move(to: CGPoint(x: 0, y: y))
            addLine(to: CGPoint(x: line.width, y: y))
        }
        strokePath()
        restoreGState()
    }

    private func draw(_ op: LargeOperatorDisplay, foregroundColor: CGColor) {
        saveGState()
        translateBy(x: op.position.x, y: op.position.y)
        draw(op.nucleus, foregroundColor: foregroundColor)
        if let upper = op.upperLimit {
            draw(upper, foregroundColor: foregroundColor)
        }
        if let lower = op.lowerLimit {
            draw(lower, foregroundColor: foregroundColor)
        }
        restoreGState()
    }
}
