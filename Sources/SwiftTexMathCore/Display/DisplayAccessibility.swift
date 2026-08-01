import Foundation

extension DisplayList {
    /// Best-effort plain-text extraction for accessibility labels (not a spoken math tree).
    ///
    /// Concatenates glyph run text in tree order. Structural nodes (rules, empty boxes)
    /// contribute nothing. Prefer the original LaTeX string for screen readers when available.
    public var accessibilityPlainText: String {
        var visitor = PlainTextVisitor()
        return accept(&visitor).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension DisplayNode {
    /// See ``DisplayList/accessibilityPlainText``.
    public var accessibilityPlainText: String {
        var visitor = PlainTextVisitor()
        return accept(&visitor).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct PlainTextVisitor: DisplayNodeVisitor {
    mutating func visit(list: DisplayList) -> String {
        list.children.map { node in
            var v = PlainTextVisitor()
            return node.accept(&v)
        }.joined()
    }

    mutating func visit(glyphs: GlyphRun) -> String {
        glyphs.text
    }

    mutating func visit(fraction: FractionDisplay) -> String {
        let num = fraction.numerator.accessibilityPlainText
        let den = fraction.denominator.accessibilityPlainText
        return "(\(num))/(\(den))"
    }

    mutating func visit(radical: RadicalDisplay) -> String {
        let body = radical.radicand.accessibilityPlainText
        if let degree = radical.degree {
            let d = degree.accessibilityPlainText
            return "root(\(d),\(body))"
        }
        return "sqrt(\(body))"
    }

    mutating func visit(line: LineDisplay) -> String {
        line.inner.accessibilityPlainText
    }

    mutating func visit(largeOperator: LargeOperatorDisplay) -> String {
        var parts = [largeOperator.nucleus.text]
        if let upper = largeOperator.upperLimit {
            parts.append("^(\(upper.accessibilityPlainText))")
        }
        if let lower = largeOperator.lowerLimit {
            parts.append("_(\(lower.accessibilityPlainText))")
        }
        return parts.joined()
    }

    mutating func visit(colored: ColoredDisplay) -> String {
        colored.inner.accessibilityPlainText
    }

    mutating func visit(rule: RuleDisplay) -> String {
        ""
    }

    mutating func visit(box: BoxDisplay) -> String {
        box.drawChild ? box.child.accessibilityPlainText : ""
    }

    mutating func visit(stack: StackDisplay) -> String {
        var parts = [stack.base.accessibilityPlainText]
        if let over = stack.over {
            parts.insert(over.accessibilityPlainText, at: 0)
        }
        if let under = stack.under {
            parts.append(under.accessibilityPlainText)
        }
        return parts.joined()
    }
}
