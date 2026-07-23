import SwiftUI
import SwiftTexMathCore

/// Typesetting style for ``Math`` views.
public enum TypesettingStyle: Sendable, Hashable {
    case display
    case text

    var mathStyle: MathStyle {
        switch self {
        case .display: return .display
        case .text: return .text
        }
    }
}

/// Rendering mode for ``Math`` views.
public enum RenderingMode: Sendable, Hashable {
    case monochrome
    case multicolor(base: Color)

    public static let multicolor = RenderingMode.multicolor(base: .primary)
}

private enum MathFontKey: EnvironmentKey {
    static let defaultValue = MathFont(name: .latinModern, size: 20)
}

private enum MathTypesettingStyleKey: EnvironmentKey {
    static let defaultValue = TypesettingStyle.display
}

private enum MathRenderingModeKey: EnvironmentKey {
    static let defaultValue = RenderingMode.monochrome
}

extension EnvironmentValues {
    public var mathFont: MathFont {
        get { self[MathFontKey.self] }
        set { self[MathFontKey.self] = newValue }
    }

    public var mathTypesettingStyle: TypesettingStyle {
        get { self[MathTypesettingStyleKey.self] }
        set { self[MathTypesettingStyleKey.self] = newValue }
    }

    public var mathRenderingMode: RenderingMode {
        get { self[MathRenderingModeKey.self] }
        set { self[MathRenderingModeKey.self] = newValue }
    }
}

extension View {
    public func mathFont(_ font: MathFont) -> some View {
        environment(\.mathFont, font)
    }

    public func mathTypesettingStyle(_ style: TypesettingStyle) -> some View {
        environment(\.mathTypesettingStyle, style)
    }

    public func mathRenderingMode(_ mode: RenderingMode) -> some View {
        environment(\.mathRenderingMode, mode)
    }
}
