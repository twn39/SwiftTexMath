import CoreGraphics
import Foundation

/// Headless entry point: parse → normalize → typeset → draw.
///
/// Pipeline order is fixed: parse produces a `MathList`, layout always runs
/// through `MathNormalizer` inside the typesetter, then builds a `DisplayList`.
/// Inject ``fonts`` for tests or alternate MATH fonts; the default is
/// ``FontRegistry/shared``.
///
/// Keep this type thin: no layout formulas or TeX command logic belong here.
public struct MathRenderer: Sendable {
    public var environment: MathEnvironment
    public var fonts: any FontProviding
    /// Predefined user macros applied on every ``parse`` / layout call (cross-parse).
    /// Macros defined via `\newcommand` inside the source still apply for that parse only
    /// and may override these for the remainder of the session.
    public var userMacros: [String: MathParser.UserMacro]

    public init(
        environment: MathEnvironment = MathEnvironment(),
        fonts: any FontProviding = FontRegistry.shared,
        userMacros: [String: MathParser.UserMacro] = [:]
    ) {
        self.environment = environment
        self.fonts = fonts
        self.userMacros = userMacros
    }

    /// Register or replace a cross-parse user macro (e.g. `\RR` → `\mathbb{R}`).
    public mutating func defineMacro(
        _ name: String,
        parameterCount: Int = 0,
        replacement: String
    ) {
        let key = name.hasPrefix("\\") ? String(name.dropFirst()) : name
        userMacros[key] = MathParser.UserMacro(
            parameterCount: parameterCount,
            replacement: replacement
        )
    }

    /// Remove a previously registered cross-parse macro.
    public mutating func removeMacro(_ name: String) {
        let key = name.hasPrefix("\\") ? String(name.dropFirst()) : name
        userMacros.removeValue(forKey: key)
    }

    public func parse(_ latex: String) throws -> MathList {
        try MathParser.parse(latex, userMacros: userMacros)
    }

    public func layout(_ list: MathList, environment: MathEnvironment? = nil) -> DisplayList {
        layoutDetailed(list, environment: environment).display
    }

    public func layout(latex: String, environment: MathEnvironment? = nil) throws -> DisplayList {
        let list = try parse(latex)
        return layout(list, environment: environment)
    }

    /// Layout plus resolved `\label` → bare equation markers (for `\ref` / diagnostics).
    public func layoutDetailed(
        _ list: MathList,
        environment: MathEnvironment? = nil
    ) -> (display: DisplayList, labels: [String: String]) {
        let result = Typesetter.createDisplayResult(
            for: list,
            environment: environment ?? self.environment,
            fonts: fonts
        )
        return (result.display, result.labels.dictionary)
    }

    /// Parse + layout with the resolved label map.
    public func layoutDetailed(
        latex: String,
        environment: MathEnvironment? = nil
    ) throws -> (display: DisplayList, labels: [String: String]) {
        let list = try parse(latex)
        return layoutDetailed(list, environment: environment)
    }

    public func draw(
        _ display: DisplayList,
        in context: CGContext,
        at origin: CGPoint,
        foregroundColor: CGColor
    ) {
        context.draw(
            display,
            at: origin,
            foregroundColor: foregroundColor,
            fonts: fonts,
            maxDepth: environment.maxRecursionDepth
        )
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
