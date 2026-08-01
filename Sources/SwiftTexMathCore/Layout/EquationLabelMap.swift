import Foundation

/// Maps `\label{name}` → bare equation marker text (e.g. `"1"`, `"A"`).
///
/// Populated by a pre-pass that mirrors auto-number / `\tag` assignment, then consumed
/// when typesetting `\ref` / `\eqref`.
public final class EquationLabelMap: @unchecked Sendable {
    private var bareByName: [String: String] = [:]

    public init() {}

    /// Bind a label name to a bare marker (digits or `\tag` body, without outer parentheses).
    public func bind(_ name: String, to bare: String) {
        guard !name.isEmpty, !bare.isEmpty else { return }
        bareByName[name] = bare
    }

    public func bareNumber(for name: String) -> String? {
        bareByName[name]
    }

    /// Display form for `\ref` (`parenthesize: false`) / `\eqref` (`parenthesize: true`).
    public func displayText(for name: String, parenthesize: Bool) -> String {
        guard let bare = bareByName[name] else {
            return parenthesize ? "(??)" : "??"
        }
        return parenthesize ? "(\(bare))" : bare
    }

    /// Snapshot of resolved labels (bare markers).
    public var dictionary: [String: String] {
        bareByName
    }
}

/// Pre-assigns equation numbers / tag markers to `\label` names so `\ref` can resolve
/// even when the reference appears before the labeled equation in the source.
enum EquationNumbering {
    static func collect(
        _ list: MathList,
        env: MathEnvironment,
        map: EquationLabelMap
    ) {
        let counter = EquationCounter(start: env.equationNumberStart)
        walkList(list, env: env, counter: counter, map: map, depth: 0)
    }

    private static func walkList(
        _ list: MathList,
        env: MathEnvironment,
        counter: EquationCounter,
        map: EquationLabelMap,
        depth: Int
    ) {
        guard depth <= env.maxRecursionDepth else { return }

        var style = env.style
        var suppress = false
        var explicitTag: MathAtom.Tag?
        var labels: [String] = []
        var hasBody = false

        for atom in list.atoms {
            switch atom.payload {
            case .style(let s):
                style = s
            case .tag(let tag):
                if tag.suppress {
                    suppress = true
                    explicitTag = nil
                } else {
                    suppress = false
                    explicitTag = tag
                }
            case .label(let name):
                labels.append(name)
            case .table(let table):
                // Nested tables are independent equation groups.
                walkTable(table, env: env, counter: counter, map: map, depth: depth + 1)
            case .space, .none:
                if !atom.nucleus.isEmpty { hasBody = true }
                walkNested(in: atom, env: env, counter: counter, map: map, depth: depth + 1)
            default:
                hasBody = true
                walkNested(in: atom, env: env, counter: counter, map: map, depth: depth + 1)
            }
        }

        // Free-standing line auto-number / explicit tag binding (top-level list only).
        if depth == 0 {
            bindLine(
                labels: labels,
                suppress: suppress,
                explicitTag: explicitTag,
                hasBody: hasBody,
                style: style,
                numberEquations: env.numberEquations,
                counter: counter,
                map: map
            )
        } else if !labels.isEmpty, let tag = explicitTag, !tag.suppress {
            // Nested lists: only bind when an explicit `\tag` is present on that list.
            let bare = bareMarker(for: tag, counter: nil)
            for name in labels { map.bind(name, to: bare) }
        }
    }

    private static func walkTable(
        _ table: MathAtom.Table,
        env: MathEnvironment,
        counter: EquationCounter,
        map: EquationLabelMap,
        depth: Int
    ) {
        let hoist = Typesetter.tableEnvironmentHoistsTags(table.environment)
        let wantsNumbers =
            Typesetter.tableEnvironmentAutoNumbers(table.environment)
            && (
                env.numberEquations
                || Typesetter.tableEnvironmentForcesNumbering(table.environment)
            )
            && (env.style == .display || Typesetter.tableEnvironmentForcesNumbering(table.environment))

        for (r, row) in table.rows.enumerated() {
            if table.fullWidthRows.contains(r) {
                // intertext: still walk nested for nested tables
                for cell in row {
                    walkList(cell, env: env, counter: counter, map: map, depth: depth + 1)
                }
                continue
            }

            let policy = Typesetter.rowTagPolicy(cells: row)
            let labels = Typesetter.rowLabelNames(cells: row)

            if hoist {
                if let explicit = policy.explicitTag {
                    let bare = bareMarker(for: explicit, counter: nil)
                    for name in labels { map.bind(name, to: bare) }
                } else if !policy.suppress, wantsNumbers {
                    let n = counter.take()
                    let bare = String(n)
                    for name in labels { map.bind(name, to: bare) }
                }
                // Walk cell bodies for nested tables (without free-standing numbering).
                for cell in row {
                    walkNestedOnly(cell, env: env, counter: counter, map: map, depth: depth + 1)
                }
            } else {
                for cell in row {
                    walkList(cell, env: env, counter: counter, map: map, depth: depth + 1)
                }
            }
        }
    }

    /// Walk nested payloads without treating the list as a free-standing numbered line.
    private static func walkNestedOnly(
        _ list: MathList,
        env: MathEnvironment,
        counter: EquationCounter,
        map: EquationLabelMap,
        depth: Int
    ) {
        guard depth <= env.maxRecursionDepth else { return }
        for atom in list.atoms {
            if case .table(let table) = atom.payload {
                walkTable(table, env: env, counter: counter, map: map, depth: depth + 1)
            } else {
                walkNested(in: atom, env: env, counter: counter, map: map, depth: depth + 1)
            }
        }
    }

    private static func walkNested(
        in atom: MathAtom,
        env: MathEnvironment,
        counter: EquationCounter,
        map: EquationLabelMap,
        depth: Int
    ) {
        if let s = atom.superscript {
            walkList(s, env: env, counter: counter, map: map, depth: depth)
        }
        if let s = atom.subscript {
            walkList(s, env: env, counter: counter, map: map, depth: depth)
        }
        switch atom.payload {
        case .fraction(let f):
            walkList(f.numerator, env: env, counter: counter, map: map, depth: depth)
            walkList(f.denominator, env: env, counter: counter, map: map, depth: depth)
        case .radical(let r):
            if let d = r.degree {
                walkList(d, env: env, counter: counter, map: map, depth: depth)
            }
            walkList(r.radicand, env: env, counter: counter, map: map, depth: depth)
        case .inner(let inner):
            walkList(inner.contents, env: env, counter: counter, map: map, depth: depth)
        case .accent(let a):
            walkList(a.base, env: env, counter: counter, map: map, depth: depth)
            if let m = a.mark {
                walkList(m, env: env, counter: counter, map: map, depth: depth)
            }
        case .overline(let list), .underline(let list):
            walkList(list, env: env, counter: counter, map: map, depth: depth)
        case .table(let table):
            walkTable(table, env: env, counter: counter, map: map, depth: depth)
        case .styled(let s):
            walkList(s.contents, env: env, counter: counter, map: map, depth: depth)
        case .colored(let c):
            walkList(c.contents, env: env, counter: counter, map: map, depth: depth)
        case .mathChoice(let c):
            walkList(c.display, env: env, counter: counter, map: map, depth: depth)
            walkList(c.text, env: env, counter: counter, map: map, depth: depth)
            walkList(c.script, env: env, counter: counter, map: map, depth: depth)
            walkList(c.scriptScript, env: env, counter: counter, map: map, depth: depth)
        case .box(let b):
            walkList(b.contents, env: env, counter: counter, map: map, depth: depth)
        case .stack(let s):
            walkList(s.base, env: env, counter: counter, map: map, depth: depth)
            if let o = s.over { walkList(o, env: env, counter: counter, map: map, depth: depth) }
            if let u = s.under { walkList(u, env: env, counter: counter, map: map, depth: depth) }
        case .tag(let t):
            walkList(t.contents, env: env, counter: counter, map: map, depth: depth)
        case .none, .largeOperator, .space, .style, .label, .ref:
            break
        }
    }

    private static func bindLine(
        labels: [String],
        suppress: Bool,
        explicitTag: MathAtom.Tag?,
        hasBody: Bool,
        style: MathStyle,
        numberEquations: Bool,
        counter: EquationCounter,
        map: EquationLabelMap
    ) {
        guard !labels.isEmpty else { return }
        if suppress { return }
        if let tag = explicitTag {
            let bare = bareMarker(for: tag, counter: nil)
            for name in labels { map.bind(name, to: bare) }
            return
        }
        if numberEquations, style == .display, hasBody {
            let bare = String(counter.take())
            for name in labels { map.bind(name, to: bare) }
        }
    }

    /// Bare marker text for a tag (auto-number uses `counter` when contents empty and auto).
    private static func bareMarker(for tag: MathAtom.Tag, counter: EquationCounter?) -> String {
        let flat = flattenList(tag.contents)
        if !flat.isEmpty { return flat }
        if let counter {
            return String(counter.take())
        }
        return ""
    }

    static func flattenList(_ list: MathList) -> String {
        var result = ""
        for atom in list.atoms {
            switch atom.payload {
            case .none, .largeOperator:
                result += atom.nucleus
            case .styled(let s):
                result += flattenList(s.contents)
            case .space:
                break
            default:
                result += atom.nucleus
            }
        }
        return result
    }
}
