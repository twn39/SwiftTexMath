import Foundation

/// Shared equation context for numbering and cross-referencing across multiple formulas.
///
/// Use `EquationContext` to share continuous equation numbering and resolve `\label` / `\ref` / `\eqref`
/// cross-references across multiple independent `MathRenderer` or `Typesetter` calls in a document.
public final class EquationContext: @unchecked Sendable, Hashable {
    private let lock = NSLock()
    public var nextEquationNumber: Int
    public var numberPrefix: String
    public var numberFormatter: (@Sendable (Int) -> String)?
    public let labelMap: EquationLabelMap

    public init(
        startNumber: Int = 1,
        numberPrefix: String = "",
        numberFormatter: (@Sendable (Int) -> String)? = nil
    ) {
        self.nextEquationNumber = max(1, startNumber)
        self.numberPrefix = numberPrefix
        self.numberFormatter = numberFormatter
        self.labelMap = EquationLabelMap()
    }

    public func takeNextNumber() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let val = nextEquationNumber
        nextEquationNumber += 1
        return val
    }

    public func formatNumber(_ value: Int) -> String {
        if let custom = numberFormatter {
            return custom(value)
        }
        if !numberPrefix.isEmpty {
            return "\(numberPrefix)\(value)"
        }
        return String(value)
    }

    public func reset(to startNumber: Int = 1) {
        lock.lock()
        defer { lock.unlock() }
        nextEquationNumber = max(1, startNumber)
    }

    public func bindLabel(_ name: String, to marker: String) {
        labelMap.bind(name, to: marker)
    }

    public func displayText(for name: String, parenthesize: Bool) -> String {
        labelMap.displayText(for: name, parenthesize: parenthesize)
    }

    public static func == (lhs: EquationContext, rhs: EquationContext) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
