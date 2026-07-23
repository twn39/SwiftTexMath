@preconcurrency import CoreGraphics
import Foundation

/// Headless entry point: parse → normalize → typeset → draw.
public struct MathRenderer: Sendable {
    public var environment: MathEnvironment

    public init(environment: MathEnvironment = MathEnvironment()) {
        self.environment = environment
    }

    public func parse(_ latex: String) throws -> MathList {
        try MathParser.parse(latex)
    }

    public func layout(_ list: MathList, environment: MathEnvironment? = nil) -> DisplayList {
        Typesetter.createDisplay(for: list, environment: environment ?? self.environment)
    }

    public func layout(latex: String, environment: MathEnvironment? = nil) throws -> DisplayList {
        let list = try parse(latex)
        return layout(list, environment: environment)
    }

    public func draw(
        _ display: DisplayList,
        in context: CGContext,
        at origin: CGPoint,
        foregroundColor: CGColor
    ) {
        context.draw(display, at: origin, foregroundColor: foregroundColor)
    }

    /// Convenience: parse + layout + draw.
    public func render(
        _ latex: String,
        in context: CGContext,
        at origin: CGPoint,
        foregroundColor: CGColor,
        environment: MathEnvironment? = nil
    ) throws {
        let display = try layout(latex: latex, environment: environment)
        // Origin is baseline-left; shift so top-left placement can use ascent.
        draw(display, in: context, at: origin, foregroundColor: foregroundColor)
    }
}
