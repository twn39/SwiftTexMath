import Foundation

/// Command / symbol tables for LaTeX math (ported from iosMath / SwiftUIMath).
///
/// Structure:
/// - `aliases` / `delimiters` / `accents` — small static maps (lookup only)
/// - `symbols` — bulk TeX control-sequence → atom table (generated at first use)
/// - `addLatexSymbol` / custom store — runtime extensions
///
/// Prefer growing the **tuple tables inside `symbols`** over new parser branches for
/// plain glyphs. Complex constructors stay in Parse `*Commands` modules.
public enum AtomFactory {
    // MARK: - Aliases & delimiters

    public static let aliases: [String: String] = AtomFactoryTables.aliases
    public static let delimiters: [String: String] = AtomFactoryTables.delimiters
    public static let accents: [String: String] = AtomFactoryTables.accents

    /// Accent commands that sit below the nucleus.
    public static let belowAccents: Set<String> = [
        "utilde", "underbar", "underrightarrow", "underleftarrow"
    ]

    public static let symbols: [String: MathAtom] = AtomFactoryTables.buildBuiltinSymbols()

    /// Thread-safe overlay for runtime-registered symbols / aliases.
    private final class CustomSymbolStore: @unchecked Sendable {
        private let lock = NSLock()
        private var symbols: [String: MathAtom] = [:]
        private var aliases: [String: String] = [:]

        func resolveAlias(_ command: String) -> String? {
            lock.lock(); defer { lock.unlock() }
            return aliases[command]
        }

        func atom(for name: String) -> MathAtom? {
            lock.lock(); defer { lock.unlock() }
            return symbols[name]
        }

        func addSymbol(_ name: String, atom: MathAtom) {
            lock.lock(); defer { lock.unlock() }
            symbols[name] = atom
        }

        func addAlias(_ name: String, target: String) {
            lock.lock(); defer { lock.unlock() }
            aliases[name] = target
        }

        func remove(_ name: String) {
            lock.lock(); defer { lock.unlock() }
            symbols.removeValue(forKey: name)
            aliases.removeValue(forKey: name)
        }

        func reset() {
            lock.lock(); defer { lock.unlock() }
            symbols.removeAll()
            aliases.removeAll()
        }

        func snapshotSymbols() -> [String: MathAtom] {
            lock.lock(); defer { lock.unlock() }
            return symbols
        }
    }

    private static let customStore = CustomSymbolStore()

    public static func resolveAlias(_ command: String) -> String {
        customStore.resolveAlias(command) ?? aliases[command] ?? command
    }

    public static func atom(forCommand command: String) -> MathAtom? {
        let name = resolveAlias(command)
        return customStore.atom(for: name) ?? symbols[name]
    }

    /// Register or replace a LaTeX command (iosMath `addLatexSymbol:`).
    /// Prefer calling during app setup before concurrent parse/layout.
    public static func addLatexSymbol(_ name: String, atom: MathAtom) {
        precondition(!name.isEmpty, "Symbol name must be non-empty")
        customStore.addSymbol(name, atom: atom)
    }

    /// Register a command alias (`name` → existing `target` command).
    public static func addAlias(_ name: String, target: String) {
        precondition(!name.isEmpty && !target.isEmpty)
        customStore.addAlias(name, target: target)
    }

    /// Remove a previously registered custom symbol (builtin symbols are unaffected).
    public static func removeLatexSymbol(_ name: String) {
        customStore.remove(name)
    }

    /// Clear all custom symbols and aliases (useful in tests).
    public static func resetCustomSymbols() {
        customStore.reset()
    }

    /// Best-effort reverse lookup of a command name for a nucleus (for serialization).
    public static func commandName(forNucleus nucleus: String, kind: AtomKind) -> String? {
        let customs = customStore.snapshotSymbols()
        for (name, atom) in customs where atom.nucleus == nucleus && atom.kind == kind {
            return name
        }
        for (name, atom) in symbols where atom.nucleus == nucleus && atom.kind == kind {
            return name
        }
        for (name, atom) in customs where atom.nucleus == nucleus {
            return name
        }
        for (name, atom) in symbols where atom.nucleus == nucleus {
            return name
        }
        return nil
    }

    public static func atom(forCharacter ch: Character) -> MathAtom? {
        if ch == "^" || ch == "_" || ch == "{" || ch == "}" || ch == "\\" {
            return nil
        }
        if ch == " " || ch == "\n" || ch == "\t" || ch == "\r" {
            return nil
        }
        if ch.isNumber {
            return .number(String(ch))
        }
        if ("a"..."z").contains(ch) || ("A"..."Z").contains(ch) {
            return .variable(String(ch))
        }
        switch ch {
        case "+", "-", "*", "/", "=":
            if ch == "=" { return .relation("=") }
            if ch == "+" || ch == "-" { return .binaryOperator(String(ch)) }
            return .binaryOperator(String(ch))
        case "<", ">":
            return .relation(String(ch))
        case "(", "[":
            return .open(String(ch))
        case ")", "]":
            return .close(String(ch))
        case ",", ";", ".", ":", "!", "?":
            return .punctuation(String(ch))
        case "|":
            return .ordinary("|")
        default:
            return .ordinary(String(ch))
        }
    }

    public static func boundaryNucleus(forDelimiter name: String) -> String? {
        delimiters[name]
    }
}
