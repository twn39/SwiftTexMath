import Testing
import SwiftUI
import SwiftTexMath
import SwiftTexMathCore

#if (canImport(UIKit) && !os(watchOS)) || (canImport(AppKit) && !targetEnvironment(macCatalyst))

@Test @MainActor
func hostedMathLabelConstructible() {
    let view = HostedMathLabel(
        #"a^2 + b^2 = c^2"#,
        mathFont: MathFont(name: .latinModern, size: 22),
        typesettingStyle: .display,
        preferredMaxLayoutWidth: 200
    )
    _ = view.body
}

#endif
