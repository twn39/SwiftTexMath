import Foundation

/// Best-effort `MathList` → LaTeX serialization (iosMath `mathListToString:`).
///
/// Round-trips common constructs; rare / layout-only payloads may lose fidelity
/// (e.g. `\cfrac` alignment, some box/strike details).
public enum LatexSerializer {
    public static func string(from list: MathList) -> String {
        var result = ""
        for atom in list.atoms {
            let piece = string(from: atom)
            if needsInterAtomSpace(before: piece, after: result) {
                result.append(" ")
            }
            result.append(piece)
        }
        return result
    }

    /// TeX control words (`\quad`, `\pi`, …) must not run into a following letter.
    private static func needsInterAtomSpace(before next: String, after previous: String) -> Bool {
        guard !previous.isEmpty, !next.isEmpty else { return false }
        guard endsWithControlWord(previous) else { return false }
        let first = next.unicodeScalars.first!
        return Character(first).isLetter || first == "\\"
    }

    private static func endsWithControlWord(_ latex: String) -> Bool {
        var i = latex.endIndex
        if i > latex.startIndex, latex[latex.index(before: i)] == "*" {
            i = latex.index(before: i)
        }
        var sawLetter = false
        while i > latex.startIndex {
            let prev = latex.index(before: i)
            let ch = latex[prev]
            if ch.isLetter {
                sawLetter = true
                i = prev
                continue
            }
            return ch == "\\" && sawLetter
        }
        return false
    }

    public static func string(from atom: MathAtom) -> String {
        var result = payloadLatex(atom)
        if let sup = atom.superscript {
            result += "^{\(string(from: sup))}"
        }
        if let sub = atom.subscript {
            result += "_{\(string(from: sub))}"
        }
        return result
    }

    private static func payloadLatex(_ atom: MathAtom) -> String {
        switch atom.payload {
        case .none:
            return nucleusLatex(atom)
        case .largeOperator:
            return nucleusLatex(atom)
        case .fraction(let frac):
            return fractionLatex(frac)
        case .radical(let rad):
            if let degree = rad.degree {
                return "\\sqrt[\(string(from: degree))]{\(string(from: rad.radicand))}"
            }
            return "\\sqrt{\(string(from: rad.radicand))}"
        case .inner(let inner):
            return innerLatex(inner)
        case .space(let mu):
            return spaceLatex(mu)
        case .style(let style):
            switch style {
            case .display: return "\\displaystyle "
            case .text: return "\\textstyle "
            case .script: return "\\scriptstyle "
            case .scriptScript: return "\\scriptscriptstyle "
            }
        case .accent(let accent):
            if let mark = accent.mark, !mark.atoms.isEmpty {
                let cmd = accent.isBelow ? "underaccent" : "accent"
                return "\\\(cmd){\(string(from: mark))}{\(string(from: accent.base))}"
            }
            let name: String
            if accent.isBelow {
                name = AtomFactory.accents.first(where: {
                    $0.value == accent.accent && AtomFactory.belowAccents.contains($0.key)
                })?.key
                ?? AtomFactory.accents.first(where: { $0.value == accent.accent })?.key
                ?? "utilde"
            } else if accent.stretchable {
                name = AtomFactory.accents.first(where: {
                    $0.value == accent.accent && $0.key.hasPrefix("wide")
                })?.key
                ?? AtomFactory.accents.first(where: { $0.value == accent.accent })?.key
                ?? "widehat"
            } else {
                name = AtomFactory.accents.first(where: {
                    $0.value == accent.accent && !$0.key.hasPrefix("wide")
                        && !AtomFactory.belowAccents.contains($0.key)
                })?.key
                ?? AtomFactory.accents.first(where: { $0.value == accent.accent })?.key
                ?? "hat"
            }
            return "\\\(name){\(string(from: accent.base))}"
        case .overline(let list):
            return "\\overline{\(string(from: list))}"
        case .underline(let list):
            return "\\underline{\(string(from: list))}"
        case .table(let table):
            return tableLatex(table)
        case .styled(let styled):
            let cmd = styleCommand(styled.variant)
            return "\\\(cmd){\(string(from: styled.contents))}"
        case .colored(let colored):
            let cmd = colored.fillsBackground ? "colorbox" : "color"
            return "\\\(cmd){\(colored.color)}{\(string(from: colored.contents))}"
        case .mathChoice(let choice):
            return """
            \\mathchoice{\(string(from: choice.display))}{\(string(from: choice.text))}\
            {\(string(from: choice.script))}{\(string(from: choice.scriptScript))}
            """
        case .box(let box):
            return boxLatex(box)
        case .stack(let stack):
            return stackLatex(stack)
        case .tag(let tag):
            let cmd = tag.parenthesize ? "tag" : "tag*"
            return "\\\(cmd){\(string(from: tag.contents))}"
        }
    }

    private static func nucleusLatex(_ atom: MathAtom) -> String {
        if atom.kind == .boundary {
            return ""
        }
        let nucleus = atom.nucleus
        if nucleus.isEmpty { return "{}" }
        if let name = AtomFactory.commandName(forNucleus: nucleus, kind: atom.kind) {
            // Single-character command tokens like \, \; need care; prefer named forms.
            if name.count == 1, !name.first!.isLetter {
                return "\\\(name)"
            }
            return "\\\(name)"
        }
        if nucleus.count == 1, let ch = nucleus.first {
            switch ch {
            case "{", "}", "\\", "$", "%", "_", "#", "&":
                return "\\\(ch)"
            default:
                return nucleus
            }
        }
        return nucleus
    }

    private static func fractionLatex(_ frac: MathAtom.Fraction) -> String {
        let num = string(from: frac.numerator)
        let den = string(from: frac.denominator)
        if !frac.leftDelimiter.isEmpty || !frac.rightDelimiter.isEmpty {
            if frac.leftDelimiter == "(", frac.rightDelimiter == ")", !frac.hasRule {
                switch frac.forcedStyle {
                case .display: return "\\dbinom{\(num)}{\(den)}"
                case .text: return "\\tbinom{\(num)}{\(den)}"
                default: return "\\binom{\(num)}{\(den)}"
                }
            }
        }
        if frac.hasRule {
            switch frac.forcedStyle {
            case .display: return "\\dfrac{\(num)}{\(den)}"
            case .text: return "\\tfrac{\(num)}{\(den)}"
            default: return "\\frac{\(num)}{\(den)}"
            }
        }
        return "{\(num)\\atop \(den)}"
    }

    private static func innerLatex(_ inner: MathAtom.Inner) -> String {
        let body = string(from: inner.contents)
        if inner.leftBoundary.isEmpty, inner.rightBoundary.isEmpty {
            return "{\(body)}"
        }
        let left = delimiterToken(inner.leftBoundary)
        let right = delimiterToken(inner.rightBoundary)
        if let height = inner.delimiterHeight {
            // Approximate sized delimiters as \left...\right (size not round-tripped).
            _ = height
        }
        return "\\left\(left)\(body)\\right\(right)"
    }

    private static func delimiterToken(_ nucleus: String) -> String {
        if nucleus.isEmpty { return "." }
        if let name = AtomFactory.delimiters.first(where: { $0.value == nucleus })?.key {
            if name.count == 1 { return name }
            return "\\\(name)"
        }
        return nucleus
    }

    private static func spaceLatex(_ mu: CGFloat) -> String {
        switch mu {
        case 3: return "\\,"
        case 4: return "\\:"
        case 5: return "\\;"
        case -3: return "\\!"
        case 18: return "\\quad"
        case 36: return "\\qquad"
        default:
            return "\\mkern{\(formatMu(mu))mu}"
        }
    }

    private static func formatMu(_ mu: CGFloat) -> String {
        if mu == mu.rounded() { return String(Int(mu)) }
        return String(format: "%.3g", Double(mu))
    }

    private static func styleCommand(_ variant: MathVariant) -> String {
        switch variant {
        case .upright: return "mathrm"
        case .bold: return "mathbf"
        case .italic: return "mathit"
        case .boldItalic: return "boldsymbol"
        case .caligraphic: return "mathcal"
        case .script: return "mathscr"
        case .fraktur: return "mathfrak"
        case .blackboard: return "mathbb"
        case .sans: return "mathsf"
        case .typewriter: return "mathtt"
        }
    }

    private static func boxLatex(_ box: MathAtom.Box) -> String {
        let body = string(from: box.contents)
        switch box.strike {
        case .forward: return "\\cancel{\(body)}"
        case .backward: return "\\bcancel{\(body)}"
        case .cross: return "\\xcancel{\(body)}"
        case .horizontal: return "\\sout{\(body)}"
        case .frame: return "\\boxed{\(body)}"
        case .none:
            break
        }
        if !box.drawChild {
            if box.keepWidth, box.keepHeight, box.keepDepth { return "\\phantom{\(body)}" }
            if box.keepWidth, !box.keepHeight, !box.keepDepth { return "\\hphantom{\(body)}" }
            if !box.keepWidth, box.keepHeight, box.keepDepth { return "\\vphantom{\(body)}" }
            return "\\phantom{\(body)}"
        }
        if !box.keepHeight || !box.keepDepth {
            return "\\smash{\(body)}"
        }
        switch box.hAlign {
        case .right: return "\\llap{\(body)}"
        case .left: return "\\rlap{\(body)}"
        case .center: return "\\clap{\(body)}"
        }
    }

    private static func stackLatex(_ stack: MathAtom.Stack) -> String {
        let base = string(from: stack.base)
        if let over = stack.over, stack.under == nil {
            return "\\overset{\(string(from: over))}{\(base)}"
        }
        if let under = stack.under, stack.over == nil {
            return "\\underset{\(string(from: under))}{\(base)}"
        }
        if let over = stack.over, let under = stack.under {
            return "\\overset{\(string(from: over))}{\\underset{\(string(from: under))}{\(base)}}"
        }
        if let nucleus = stack.overNucleus {
            let name = AtomFactory.commandName(forNucleus: nucleus, kind: .ordinary) ?? "overrightarrow"
            return "\\\(name){\(base)}"
        }
        if let nucleus = stack.underNucleus {
            let name = AtomFactory.commandName(forNucleus: nucleus, kind: .ordinary) ?? "underbrace"
            return "\\\(name){\(base)}"
        }
        return "{\(base)}"
    }

    private static func tableLatex(_ table: MathAtom.Table) -> String {
        var body = ""
        for (r, row) in table.rows.enumerated() {
            if r > 0 { body += " \\\\" }
            for (c, cell) in row.enumerated() {
                if c > 0 { body += " & " }
                body += string(from: cell)
            }
        }
        let env = table.environment
        if env == "array" {
            let spec = table.alignments.map {
                switch $0 {
                case .left: return "l"
                case .center: return "c"
                case .right: return "r"
                }
            }.joined()
            return "\\begin{array}{\(spec)}\(body)\\end{array}"
        }
        return "\\begin{\(env)}\(body)\\end{\(env)}"
    }
}

extension MathList {
    /// Serialize this list back to LaTeX (best-effort).
    public var latexString: String {
        LatexSerializer.string(from: self)
    }
}
