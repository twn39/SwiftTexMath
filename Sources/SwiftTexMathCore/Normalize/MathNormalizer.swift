import Foundation

/// TeX Appendix G Rules 5–6 and number fusion (iosMath `finalized` / preprocess).
///
/// Also drops bare `.boundary` atoms outside `\left...\right` (illegal `\middle`),
/// while preserving boundaries nested inside `.inner` fences for delimiter layout.
///
/// **Payload discipline:** this stage is the preferred place to lower parse sugar into
/// layout-ready shapes so `Typesetter` / `*Layout` switches stay smaller. Prefer
/// expanding normalize rules over adding TeX-facing cases that Layout must special-case.
public enum MathNormalizer {
    /// Produce a layout-ready list: fuse numbers, reclassify Bin→Ord, recurse into nested lists.
    public static func normalize(_ list: MathList) -> MathList {
        normalize(list, preserveBoundaries: false)
    }

    private static func normalize(_ list: MathList, preserveBoundaries: Bool) -> MathList {
        var result = MathList()
        var previous: MathAtom?

        for raw in list.atoms {
            // `\middle` only belongs inside `\left...\right`; drop stray boundaries elsewhere.
            if !preserveBoundaries, raw.kind == .boundary {
                continue
            }

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
        atom.superscript = atom.superscript.map { normalize($0, preserveBoundaries: false) }
        atom.subscript = atom.subscript.map { normalize($0, preserveBoundaries: false) }

        switch atom.payload {
        case .fraction(var f):
            f.numerator = normalize(f.numerator, preserveBoundaries: false)
            f.denominator = normalize(f.denominator, preserveBoundaries: false)
            atom.payload = .fraction(f)
        case .radical(var r):
            r.degree = r.degree.map { normalize($0, preserveBoundaries: false) }
            r.radicand = normalize(r.radicand, preserveBoundaries: false)
            atom.payload = .radical(r)
        case .inner(var inner):
            // Keep `\middle` boundary atoms for DelimiterLayout.splitOnBoundaries.
            inner.contents = normalize(inner.contents, preserveBoundaries: true)
            atom.payload = .inner(inner)
        case .accent(var accent):
            accent.base = normalize(accent.base, preserveBoundaries: false)
            if let mark = accent.mark {
                accent.mark = normalize(mark, preserveBoundaries: false)
            }
            atom.payload = .accent(accent)
        case .overline(let list):
            atom.payload = .overline(normalize(list, preserveBoundaries: false))
        case .underline(let list):
            atom.payload = .underline(normalize(list, preserveBoundaries: false))
        case .table(var table):
            table.rows = table.rows.map { $0.map { normalize($0, preserveBoundaries: false) } }
            atom.payload = .table(table)
        case .styled(var styled):
            styled.contents = normalize(styled.contents, preserveBoundaries: false)
            atom.payload = .styled(styled)
        case .colored(var colored):
            colored.contents = normalize(colored.contents, preserveBoundaries: false)
            atom.payload = .colored(colored)
        case .mathChoice(var choice):
            choice.display = normalize(choice.display, preserveBoundaries: false)
            choice.text = normalize(choice.text, preserveBoundaries: false)
            choice.script = normalize(choice.script, preserveBoundaries: false)
            choice.scriptScript = normalize(choice.scriptScript, preserveBoundaries: false)
            atom.payload = .mathChoice(choice)
        case .box(var box):
            box.contents = normalize(box.contents, preserveBoundaries: false)
            atom.payload = .box(box)
        case .stack(var stack):
            stack.base = normalize(stack.base, preserveBoundaries: false)
            stack.over = stack.over.map { normalize($0, preserveBoundaries: false) }
            stack.under = stack.under.map { normalize($0, preserveBoundaries: false) }
            atom.payload = .stack(stack)
        case .tag(var tag):
            tag.contents = normalize(tag.contents, preserveBoundaries: false)
            atom.payload = .tag(tag)
        case .none, .largeOperator, .space, .style:
            break
        }
        return atom
    }
}
