import CoreGraphics
import Foundation

/// Bundles environment + base metrics for layout helpers (avoids ad-hoc FontRegistry lookups).
struct LayoutContext {
    var env: MathEnvironment
    var metrics: FontMetrics

    func styleMetrics(for env: MathEnvironment) -> FontMetrics {
        let font = MathFont(name: env.font.name, size: env.styleFontSize)
        return FontRegistry.shared.metrics(for: font)
            ?? FontRegistry.shared.metrics(for: env.font)
            ?? metrics
    }

    func childTypesetter() -> (MathList, MathEnvironment) -> DisplayList {
        { list, childEnv in
            let m = self.styleMetrics(for: childEnv)
            return Typesetter.typeset(list, env: childEnv, metrics: m)
        }
    }
}
