import CoreGraphics
import Foundation
import Testing
@testable import SwiftTexMathCore

/// Catalog of committed PNG goldens under `Tests/SwiftTexMathCoreTests/Goldens/`.
enum GoldenFixtures {
    struct Case: Sendable {
        var name: String
        var latex: String
        var style: MathStyle
        var fontSize: CGFloat
        var maxWidth: CGFloat

        var fileName: String { "\(name).png" }
    }

    static let all: [Case] = [
        .init(name: "simple_equals", latex: #"E = mc^2"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "fraction", latex: #"\frac{a+1}{b+2}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "quadratic", latex: #"x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "pmatrix", latex: #"\begin{pmatrix} 1 & 0 \\ 0 & 1 \end{pmatrix}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "colorbox", latex: #"\colorbox{#ffcc00}{x^2}"#, style: .display, fontSize: 24, maxWidth: 0),
        .init(name: "middle", latex: #"\left( a \middle| b \right)"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "operatorname", latex: #"\operatorname{Hom}(A,B)"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "wrapped", latex: #"a = b = c = d = e = f = g"#, style: .display, fontSize: 18, maxWidth: 70),
        .init(name: "overset", latex: #"\overset{def}{=}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "cancel", latex: #"\cancel{abc}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "array_vlines", latex: #"\begin{array}{|c|c|} a & b \\ c & d \end{array}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "aligned", latex: #"\begin{aligned} a &= b \\ c &= d \end{aligned}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "big_delims", latex: #"\left( \frac{a}{b} \middle| \frac{c}{d} \right)"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "phantom_smash", latex: #"a\phantom{x}b\smash{y}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "primes", latex: #"f'(x)+g''(x)"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "oiint", latex: #"\oiint_S F\cdot dS"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "cfrac", latex: #"\cfrac[l]{1}{1+\cfrac{1}{x}}"#, style: .display, fontSize: 18, maxWidth: 0),
        .init(name: "array_at", latex: #"\begin{array}{c@{\,}c} a & b \end{array}"#, style: .display, fontSize: 20, maxWidth: 0),
        // Expanded visual coverage
        .init(name: "binom", latex: #"\binom{n}{k}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "sum_limits", latex: #"\sum_{i=1}^{n} i"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "int_limits", latex: #"\int_0^1 x\,dx"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "bmatrix", latex: #"\begin{bmatrix} 1 & 2 \\ 3 & 4 \end{bmatrix}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "cases", latex: #"\begin{cases} x & x>0 \\ -x & x\le 0 \end{cases}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "sqrt_frac", latex: #"\sqrt{\frac{a}{b}}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "underbrace", latex: #"\underbrace{a+b+c}_{3}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "overrightarrow", latex: #"\overrightarrow{AB}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "hat_multi", latex: #"\hat{xyz}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "sin_identity", latex: #"\sin^2\theta+\cos^2\theta=1"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "left_right_frac", latex: #"\left(\frac{a}{b}\right)"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "tag_display", latex: #"a+b=c\tag{1}"#, style: .display, fontSize: 20, maxWidth: 120),
        .init(name: "align_env", latex: #"\begin{aligned} a&=b\\ c&=d \end{aligned}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "nested_scripts", latex: #"x^{y^z}"#, style: .display, fontSize: 20, maxWidth: 0),
        .init(name: "mathbb_set", latex: #"x\in\mathbb{R}"#, style: .display, fontSize: 20, maxWidth: 0)
    ]

    static let renderOptions = MathImage.Options(
        scale: 2,
        padding: 2,
        foregroundColor: CGColor(gray: 0, alpha: 1),
        backgroundColor: CGColor(gray: 1, alpha: 1)
    )

    static func render(_ fixture: Case) throws -> CGImage {
        let env = MathEnvironment(
            font: MathFont(name: .latinModern, size: fixture.fontSize),
            style: fixture.style,
            maxWidth: fixture.maxWidth
        )
        return try MathImage.render(
            latex: fixture.latex,
            environment: env,
            options: renderOptions
        ).image
    }

    static func goldensDirectoryURL() -> URL {
        // Prefer writing next to the source fixtures when regenerating.
        let src = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Goldens", isDirectory: true)
        return src
    }

    static func bundledGoldenURL(_ fixture: Case) -> URL? {
        Bundle.module.url(forResource: fixture.name, withExtension: "png", subdirectory: nil)
            ?? Bundle.module.url(forResource: fixture.name, withExtension: "png", subdirectory: "Goldens")
    }
}

@Test func goldenPNGsMatchCommittedFixtures() throws {
    let regenerate = ProcessInfo.processInfo.environment["REGENERATE_GOLDENS"] == "1"
    let outDir = GoldenFixtures.goldensDirectoryURL()

    if regenerate {
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    for fixture in GoldenFixtures.all {
        let actual = try GoldenFixtures.render(fixture)
        guard let png = MathImage.pngData(from: actual) else {
            Issue.record("Failed to encode PNG for \(fixture.name)")
            continue
        }

        if regenerate {
            let url = outDir.appendingPathComponent(fixture.fileName)
            try png.write(to: url)
            continue
        }

        guard let goldenURL = GoldenFixtures.bundledGoldenURL(fixture) else {
            Issue.record(
                "Missing golden \(fixture.fileName). Run: REGENERATE_GOLDENS=1 swift test --filter goldenPNGs"
            )
            continue
        }
        let goldenData = try Data(contentsOf: goldenURL)
        guard let expected = MathImage.image(fromPNG: goldenData) else {
            Issue.record("Could not decode golden \(fixture.fileName)")
            continue
        }

        #expect(
            actual.width == expected.width && actual.height == expected.height,
            Comment(rawValue: "Size mismatch for \(fixture.name): \(actual.width)x\(actual.height) vs \(expected.width)x\(expected.height)")
        )
        #expect(
            MathImage.matches(actual, expected),
            Comment(rawValue: "Pixel mismatch for \(fixture.name)")
        )
    }
}

@Test func goldenPNGRoundTripStable() throws {
    let image = try GoldenFixtures.render(GoldenFixtures.all[0])
    guard let data = MathImage.pngData(from: image),
          let decoded = MathImage.image(fromPNG: data)
    else {
        Issue.record("PNG round-trip failed")
        return
    }
    #expect(MathImage.matches(image, decoded, maxDifferingFraction: 0, maxChannelDelta: 0)
                || MathImage.matches(image, decoded, maxDifferingFraction: 0.001, maxChannelDelta: 2))
}
