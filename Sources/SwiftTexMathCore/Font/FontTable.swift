import Foundation

/// OpenType MATH table constants / variants baked to plist (iosMath schema).
struct FontTable: Codable, Sendable {
    struct Assembly: Codable, Sendable {
        struct Part: Codable, Sendable {
            let advance: Int
            let endConnector: Int
            let extender: Bool
            let glyph: String
            let startConnector: Int
        }

        let italic: Int
        let parts: [Part]
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case accents
        case constants
        case italic
        case hVariants = "h_variants"
        case vVariants = "v_variants"
        case vAssembly = "v_assembly"
        case hAssembly = "h_assembly"
    }

    let version: String
    let accents: [String: Int]
    let constants: [String: Int]
    let italic: [String: Int]
    let hVariants: [String: [String]]
    let vVariants: [String: [String]]
    let vAssembly: [String: Assembly]
    /// Horizontal glyph constructions (stretchy arrows, braces, wide bars). Optional in some fonts.
    let hAssembly: [String: Assembly]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(String.self, forKey: .version)
        accents = try c.decode([String: Int].self, forKey: .accents)
        constants = try c.decode([String: Int].self, forKey: .constants)
        italic = try c.decode([String: Int].self, forKey: .italic)
        hVariants = try c.decode([String: [String]].self, forKey: .hVariants)
        vVariants = try c.decode([String: [String]].self, forKey: .vVariants)
        vAssembly = try c.decode([String: Assembly].self, forKey: .vAssembly)
        hAssembly = try c.decodeIfPresent([String: Assembly].self, forKey: .hAssembly) ?? [:]
    }
}
