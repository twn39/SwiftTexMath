import CoreGraphics
import Foundation

/// Bundles environment + base metrics for layout helpers (avoids ad-hoc FontRegistry lookups).
struct LayoutContext {
    var env: MathEnvironment
    var metrics: FontMetrics
    var fonts: any FontProviding

    init(env: MathEnvironment, metrics: FontMetrics, fonts: any FontProviding = FontRegistry.shared) {
        self.env = env
        self.metrics = metrics
        self.fonts = fonts
    }

    func styleMetrics(for env: MathEnvironment) -> FontMetrics {
        let font = MathFont(name: env.font.name, size: env.styleFontSize)
        return fonts.metrics(for: font)
            ?? fonts.metrics(for: env.font)
            ?? metrics
    }

    func childTypesetter() -> (MathList, MathEnvironment) -> DisplayList {
        { list, childEnv in
            let m = self.styleMetrics(for: childEnv)
            return Typesetter.typeset(list, env: childEnv, metrics: m, fonts: self.fonts)
        }
    }
}
