import Foundation

/// TeX Appendix G Rules 5–6 and number fusion (iosMath `finalized` / preprocess).
public enum MathNormalizer {
    /// Produce a layout-ready list: fuse numbers, reclassify Bin→Ord, recurse into nested lists.
    public static func normalize(_ list: MathList) -> MathList {
        var result = MathList()
        var previous: MathAtom?

        for raw in list.atoms {
            var atom = normalizeAtom(raw)

            switch atom.kind {
            case .binaryOperator:
                if previous == nil || previous!.kind.disallowsFollowingBinaryOperator {
                    atom.kind = .ordinary
                }
            case .relation, .punctuation, .close:
                if var prev = previous, prev.kind == .binaryOperator {
                    prev.kind = .ordinary
                    if !result.atoms.isEmpty {
                        result.atoms[result.atoms.count - 1] = prev
                    }
                    previous = prev
                }
            case .number:
                if var prev = previous, prev.kind == .number,
                   prev.superscript == nil, prev.subscript == nil,
                   atom.superscript == nil, atom.subscript == nil {
                    prev.nucleus += atom.nucleus
                    result.atoms[result.atoms.count - 1] = prev
                    previous = prev
                    continue
                }
            default:
                break
            }

            result.append(atom)
            previous = atom
        }

        if var last = previous, last.kind == .binaryOperator {
            last.kind = .ordinary
            if !result.atoms.isEmpty {
                result.atoms[result.atoms.count - 1] = last
            }
        }

        // Collapse number/variable → ordinary for spacing (after fusion).
        for i in result.atoms.indices {
            if result.atoms[i].kind == .number || result.atoms[i].kind == .variable {
                result.atoms[i].kind = .ordinary
            }
        }

        return result
    }

    private static func normalizeAtom(_ atom: MathAtom) -> MathAtom {
        var atom = atom
        atom.superscript = atom.superscript.map(normalize)
        atom.subscript = atom.subscript.map(normalize)

        switch atom.payload {
        case .fraction(var f):
            f.numerator = normalize(f.numerator)
            f.denominator = normalize(f.denominator)
            atom.payload = .fraction(f)
        case .radical(var r):
            r.degree = r.degree.map(normalize)
            r.radicand = normalize(r.radicand)
            atom.payload = .radical(r)
        case .inner(var inner):
            inner.contents = normalize(inner.contents)
            atom.payload = .inner(inner)
        case .accent(var accent):
            accent.base = normalize(accent.base)
            atom.payload = .accent(accent)
        case .overline(let list):
            atom.payload = .overline(normalize(list))
        case .underline(let list):
            atom.payload = .underline(normalize(list))
        case .table(var table):
            table.rows = table.rows.map { $0.map(normalize) }
            atom.payload = .table(table)
        case .styled(var styled):
            styled.contents = normalize(styled.contents)
            atom.payload = .styled(styled)
        case .colored(var colored):
            colored.contents = normalize(colored.contents)
            atom.payload = .colored(colored)
        case .mathChoice(var choice):
            choice.display = normalize(choice.display)
            choice.text = normalize(choice.text)
            choice.script = normalize(choice.script)
            choice.scriptScript = normalize(choice.scriptScript)
            atom.payload = .mathChoice(choice)
        case .box(var box):
            box.contents = normalize(box.contents)
            atom.payload = .box(box)
        case .stack(var stack):
            stack.base = normalize(stack.base)
            stack.over = stack.over.map(normalize)
            stack.under = stack.under.map(normalize)
            atom.payload = .stack(stack)
        case .none, .largeOperator, .space, .style:
            break
        }
        return atom
    }
}
