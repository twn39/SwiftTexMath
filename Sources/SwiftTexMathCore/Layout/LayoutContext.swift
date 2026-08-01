import CoreGraphics
import Foundation

/// Bundles environment + base metrics for layout helpers (avoids ad-hoc FontRegistry lookups).
struct LayoutContext {
    var env: MathEnvironment
    var metrics: FontMetrics
    var fonts: any FontProviding
    var depth: Int
    /// Shared auto-number sequence when ``MathEnvironment/numberEquations`` is enabled.
    var equationCounter: EquationCounter?
    /// Resolved `\label` → bare equation markers for `\ref` / `\eqref`.
    var labelMap: EquationLabelMap?

    init(
        env: MathEnvironment,
        metrics: FontMetrics,
        fonts: any FontProviding = FontRegistry.shared,
        depth: Int = 0,
        equationCounter: EquationCounter? = nil,
        labelMap: EquationLabelMap? = nil
    ) {
        self.env = env
        self.metrics = metrics
        self.fonts = fonts
        self.depth = depth
        self.equationCounter = equationCounter
        self.labelMap = labelMap
    }

    func styleMetrics(for env: MathEnvironment) -> FontMetrics {
        let font = MathFont(name: env.font.name, size: env.styleFontSize)
        return fonts.metrics(for: font)
            ?? fonts.metrics(for: env.font)
            ?? metrics
    }

    func childTypesetter() -> (MathList, MathEnvironment) -> DisplayList {
        { list, childEnv in
            let nextDepth = self.depth + 1
            if nextDepth > childEnv.maxRecursionDepth {
                return DisplayList()
            }
            let m = self.styleMetrics(for: childEnv)
            return Typesetter.typeset(
                list,
                env: childEnv,
                metrics: m,
                fonts: self.fonts,
                depth: nextDepth,
                equationCounter: self.equationCounter,
                labelMap: self.labelMap
            )
        }
    }
}
