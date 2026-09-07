import Foundation

/// Shared limits for recursive display-tree walks (draw, SVG emit, visitors).
///
/// Layout already caps recursion via ``MathEnvironment/maxRecursionDepth``. Emitters
/// and CoreGraphics drawing use this default so pathological display trees cannot
/// blow the stack outside the typesetter.
public enum DisplayTraversal {
    /// Default maximum nesting depth for drawing / SVG emission.
    public static let defaultMaxDepth = 128
}

/// Shared mutable equation counter for amsmath-style auto-numbering during layout.
///
/// Held by reference so nested table/row layout shares one sequence.
final class EquationCounter: @unchecked Sendable {
    var next: Int
    var format: (@Sendable (Int) -> String)?

    init(start: Int = 1, format: (@Sendable (Int) -> String)? = nil) {
        self.next = max(1, start)
        self.format = format
    }

    func take() -> Int {
        let value = next
        next += 1
        return value
    }

    func takeString() -> String {
        let value = take()
        return format?(value) ?? String(value)
    }
}
