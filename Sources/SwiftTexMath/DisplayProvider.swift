import SwiftUI
import SwiftTexMathCore

/// Caches parse + layout results for SwiftUI layout/draw passes.
///
/// Automatically caches results across layout passes for default and custom ``FontProviding``
/// implementations to avoid redundant layout calculations.
enum DisplayProvider {
    struct Key: Hashable, Sendable {
        var latex: String
        var font: MathFont
        var style: TypesettingStyle
        var proposedWidth: CGFloat
        var fontProviderID: ObjectIdentifier
        var textFallbackFontName: String?
    }

    private final class CacheBox: @unchecked Sendable {
        let lock = NSLock()
        var storage: [Key: Result<DisplayList, ParseError>] = [:]
        var order: [Key] = []
        let capacity = 256

        func get(_ key: Key) -> Result<DisplayList, ParseError>? {
            lock.lock()
            defer { lock.unlock() }
            return storage[key]
        }

        func set(_ key: Key, _ value: Result<DisplayList, ParseError>) {
            lock.lock()
            defer { lock.unlock() }
            if storage[key] == nil {
                order.append(key)
            }
            storage[key] = value
            while order.count > capacity {
                let evicted = order.removeFirst()
                storage.removeValue(forKey: evicted)
            }
        }
    }

    private static let cache = CacheBox()

    private static func fontProviderIdentifier(_ fonts: any FontProviding) -> ObjectIdentifier {
        if let obj = fonts as? AnyObject {
            return ObjectIdentifier(obj)
        }
        return ObjectIdentifier(type(of: fonts))
    }

    static func display(
        for latex: String,
        font: MathFont,
        style: TypesettingStyle,
        proposedWidth: CGFloat,
        fonts: any FontProviding = FontRegistry.shared,
        textFallbackFontName: String? = nil
    ) -> Result<DisplayList, ParseError> {
        let providerID = fontProviderIdentifier(fonts)
        let effectiveMaxWidth: CGFloat
        if !proposedWidth.isFinite || proposedWidth <= 0 || style == .display {
            effectiveMaxWidth = 0
        } else {
            effectiveMaxWidth = proposedWidth
        }
        let key = Key(
            latex: latex,
            font: font,
            style: style,
            proposedWidth: effectiveMaxWidth.rounded(),
            fontProviderID: providerID,
            textFallbackFontName: textFallbackFontName
        )
        if let cached = cache.get(key) {
            return cached
        }

        let env = MathEnvironment(
            font: font,
            style: style.mathStyle,
            maxWidth: effectiveMaxWidth,
            textFallbackFontName: textFallbackFontName
        )
        let result: Result<DisplayList, ParseError>
        do {
            let list = try MathParser.parse(latex)
            result = .success(Typesetter.createDisplay(for: list, environment: env, fonts: fonts))
        } catch let error as ParseError {
            result = .failure(error)
        } catch {
            result = .failure(ParseError(code: .internalError, message: error.localizedDescription))
        }

        cache.set(key, result)
        return result
    }
}
