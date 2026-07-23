@preconcurrency import CoreGraphics
@preconcurrency import CoreText
import Foundation

/// Thread-safe loader for bundled math fonts + MATH plists.
public final class FontRegistry: @unchecked Sendable {
    public static let shared = FontRegistry()

    private let lock = NSLock()
    private var graphicsFonts: [MathFont.Name: CGFont] = [:]
    private var tables: [MathFont.Name: FontTable] = [:]
    private var ctFonts: [String: CTFont] = [:]

    private init() {}

    public func metrics(for font: MathFont) -> FontMetrics? {
        lock.lock()
        defer { lock.unlock() }

        guard
            let cgFont = graphicsFonts[font.name] ?? register(name: font.name)?.0,
            let table = tables[font.name]
        else {
            return nil
        }

        let key = "\(font.name.rawValue)#\(font.size)"
        let ctFont: CTFont
        if let cached = ctFonts[key] {
            ctFont = cached
        } else {
            ctFont = CTFontCreateWithGraphicsFont(cgFont, font.size, nil, nil)
            ctFonts[key] = ctFont
        }

        let units = UInt(cgFont.unitsPerEm)
        return FontMetrics(font: font, unitsPerEm: units, table: table, ctFont: ctFont, cgFont: cgFont)
    }

    private func register(name: MathFont.Name) -> (CGFont, FontTable)? {
        guard
            let bundleURL = Bundle.module.url(forResource: "mathFonts", withExtension: "bundle"),
            let resourceBundle = Bundle(url: bundleURL),
            let otfURL = resourceBundle.url(forResource: name.rawValue, withExtension: "otf"),
            let plistURL = resourceBundle.url(forResource: name.rawValue, withExtension: "plist"),
            let data = try? Data(contentsOf: otfURL),
            let provider = CGDataProvider(data: data as CFData),
            let cgFont = CGFont(provider),
            let plistData = try? Data(contentsOf: plistURL),
            let table = try? PropertyListDecoder().decode(FontTable.self, from: plistData)
        else {
            return nil
        }

        CTFontManagerRegisterGraphicsFont(cgFont, nil)
        graphicsFonts[name] = cgFont
        tables[name] = table
        return (cgFont, table)
    }
}
