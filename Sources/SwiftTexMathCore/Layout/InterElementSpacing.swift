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
    private static let table: [[InterElementSpaceType]] = [
        // ordinary, operator, binary, relation, open, close, punct, fraction
        [.none, .thin, .nsMedium, .nsThick, .none, .none, .none, .nsThin], // ordinary
        [.thin, .thin, .invalid, .nsThick, .none, .none, .none, .nsThin], // operator
        [.nsMedium, .nsMedium, .invalid, .invalid, .nsMedium, .invalid, .invalid, .nsMedium], // binary
        [.nsThick, .nsThick, .invalid, .none, .nsThick, .none, .none, .nsThick], // relation
        [.none, .none, .invalid, .none, .none, .none, .none, .none], // open
        [.none, .thin, .nsMedium, .nsThick, .none, .none, .none, .nsThin], // close
        [.nsThin, .nsThin, .invalid, .nsThin, .nsThin, .nsThin, .nsThin, .nsThin], // punct
        [.nsThin, .thin, .nsMedium, .nsThick, .nsThin, .none, .nsThin, .nsThin], // fraction
        [.nsMedium, .nsThin, .nsMedium, .nsThick, .none, .none, .none, .nsThin] // radical (left)
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
        let type = table[row][col]
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
