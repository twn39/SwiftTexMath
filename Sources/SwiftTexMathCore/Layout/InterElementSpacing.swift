import CoreGraphics
import Foundation

enum InterElementSpaceType: Int {
    case invalid = -1
    case none = 0
    case thin
    case nsThin
    case nsMedium
    case nsThick
}

/// TeX Chapter 18 inter-element spacing matrix (iosMath / SwiftUIMath).
enum InterElementSpacing {
    // 9 rows x 8 columns = 72 elements
    private static let table: [InterElementSpaceType] = [
        // ordinary
        .none, .thin, .nsMedium, .nsThick, .none, .none, .none, .nsThin,
        // operator
        .thin, .thin, .invalid, .nsThick, .none, .none, .none, .nsThin,
        // binary
        .nsMedium, .nsMedium, .invalid, .invalid, .nsMedium, .invalid, .invalid, .nsMedium,
        // relation
        .nsThick, .nsThick, .invalid, .none, .nsThick, .none, .none, .nsThick,
        // open
        .none, .none, .invalid, .none, .none, .none, .none, .none,
        // close
        .none, .thin, .nsMedium, .nsThick, .none, .none, .none, .nsThin,
        // punct
        .nsThin, .nsThin, .invalid, .nsThin, .nsThin, .nsThin, .nsThin, .nsThin,
        // fraction
        .nsThin, .thin, .nsMedium, .nsThick, .nsThin, .none, .nsThin, .nsThin,
        // radical (left)
        .nsMedium, .nsThin, .nsMedium, .nsThick, .none, .none, .none, .nsThin
    ]

    static func space(
        left: AtomKind,
        right: AtomKind,
        style: MathStyle,
        parameters: MathParameters,
        mathUnit: CGFloat
    ) -> CGFloat {
        let row = left.spacingKind.spacingIndex(isLeft: true)
        let col = right.spacingKind.spacingIndex(isLeft: false)
        let type = table[row * 8 + col]
        let mu: CGFloat
        switch type {
        case .invalid, .none:
            return 0
        case .thin:
            mu = parameters.thinMuskip
        case .nsThin:
            mu = style.isScript ? 0 : parameters.thinMuskip
        case .nsMedium:
            mu = style.isScript ? 0 : parameters.medMuskip
        case .nsThick:
            mu = style.isScript ? 0 : parameters.thickMuskip
        }
        return mu * mathUnit
    }
}
