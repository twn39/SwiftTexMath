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

    init(start: Int = 1) {
        self.next = max(1, start)
    }

    func take() -> Int {
        let value = next
        next += 1
        return value
    }
}
