import Foundation

/// A visitor interface for traversing `DisplayList` / `DisplayNode` tree hierarchies.
///
/// Implement this protocol to perform custom traversals, rendering, hit-testing,
/// or text extraction over laid-out math display trees without switching manually
/// on `DisplayNode` enum cases.
public protocol DisplayNodeVisitor {
    associatedtype Result

    mutating func visit(list: DisplayList) -> Result
    mutating func visit(glyphs: GlyphRun) -> Result
    mutating func visit(fraction: FractionDisplay) -> Result
    mutating func visit(radical: RadicalDisplay) -> Result
    mutating func visit(line: LineDisplay) -> Result
    mutating func visit(largeOperator: LargeOperatorDisplay) -> Result
    mutating func visit(colored: ColoredDisplay) -> Result
    mutating func visit(rule: RuleDisplay) -> Result
    mutating func visit(box: BoxDisplay) -> Result
    mutating func visit(stack: StackDisplay) -> Result
}

extension DisplayNode {
    /// Accepts a visitor to process this display node.
    public func accept<V: DisplayNodeVisitor>(_ visitor: inout V) -> V.Result {
        switch self {
        case .list(let list):
            return visitor.visit(list: list)
        case .glyphs(let run):
            return visitor.visit(glyphs: run)
        case .fraction(let fraction):
            return visitor.visit(fraction: fraction)
        case .radical(let radical):
            return visitor.visit(radical: radical)
        case .line(let line):
            return visitor.visit(line: line)
        case .largeOperator(let op):
            return visitor.visit(largeOperator: op)
        case .colored(let colored):
            return visitor.visit(colored: colored)
        case .rule(let rule):
            return visitor.visit(rule: rule)
        case .box(let box):
            return visitor.visit(box: box)
        case .stack(let stack):
            return visitor.visit(stack: stack)
        }
    }
}

extension DisplayList {
    /// Accepts a visitor to process this display list.
    public func accept<V: DisplayNodeVisitor>(_ visitor: inout V) -> V.Result {
        visitor.visit(list: self)
    }
}
