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
