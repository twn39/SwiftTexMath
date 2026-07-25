import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Renders laid-out math into a bitmap (`CGImage`) for previews, exports, and snapshot tests.
public enum MathImage {
    public struct Options: Sendable {
        public var scale: CGFloat
        public var padding: CGFloat
        public var foregroundColor: CGColor
        public var backgroundColor: CGColor?

        public init(
            scale: CGFloat = 2,
            padding: CGFloat = 2,
            foregroundColor: CGColor = CGColor(gray: 0, alpha: 1),
            backgroundColor: CGColor? = CGColor(gray: 1, alpha: 1)
        ) {
            self.scale = scale
            self.padding = padding
            self.foregroundColor = foregroundColor
            self.backgroundColor = backgroundColor
        }
    }

    public struct Result: Sendable {
        public var image: CGImage
        public var display: DisplayList
        /// Logical size in points (not pixels).
        public var size: CGSize

        public init(image: CGImage, display: DisplayList, size: CGSize) {
            self.image = image
            self.display = display
            self.size = size
        }
    }

    /// Parse + layout + rasterize.
    public static func render(
        latex: String,
        environment: MathEnvironment = MathEnvironment(),
        fonts: any FontProviding = FontRegistry.shared,
        options: Options = Options()
    ) throws -> Result {
        let renderer = MathRenderer(environment: environment, fonts: fonts)
        let display = try renderer.layout(latex: latex)
        return render(display: display, fonts: fonts, options: options)
    }

    private final class BitmapBufferPool: @unchecked Sendable {
        private struct BufferEntry {
            var capacity: Int
            var data: [UInt8]
        }
        private let lock = NSLock()
        private var storage: [BufferEntry] = []
        private let capacity = 16

        func acquire(byteCount: Int) -> [UInt8] {
            lock.lock()
            defer { lock.unlock() }
            if let idx = storage.firstIndex(where: { $0.capacity >= byteCount }) {
                let entry = storage.remove(at: idx)
                var buf = entry.data
                buf.withUnsafeMutableBufferPointer { ptr in
                    ptr.baseAddress?.initialize(repeating: 0, count: byteCount)
                }
                return buf
            }
            return [UInt8](repeating: 0, count: byteCount)
        }

        func release(_ buffer: [UInt8]) {
            lock.lock()
            defer { lock.unlock() }
            guard storage.count < capacity else { return }
            storage.append(BufferEntry(capacity: buffer.count, data: buffer))
        }
    }

    private static let bufferPool = BitmapBufferPool()

    /// Rasterize an existing display list.
    public static func render(
        display: DisplayList,
        fonts: any FontProviding = FontRegistry.shared,
        options: Options = Options()
    ) -> Result {
        let pad = max(options.padding, 0)
        let scale = max(options.scale, 1)
        let pointWidth = max(display.width + 2 * pad, 1)
        let pointHeight = max(display.ascent + display.descent + 2 * pad, 1)
        let pixelWidth = max(Int(ceil(pointWidth * scale)), 1)
        let pixelHeight = max(Int(ceil(pointHeight * scale)), 1)

        let bytesPerRow = pixelWidth * 4
        let totalBytes = bytesPerRow * pixelHeight
        var buffer = bufferPool.acquire(byteCount: totalBytes)
        defer { bufferPool.release(buffer) }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: &buffer,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            // Fallback empty 1×1 image should not happen on Apple platforms.
            let empty = CGContext(
                data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
                space: colorSpace, bitmapInfo: bitmapInfo
            )!
            return Result(
                image: empty.makeImage()!,
                display: display,
                size: CGSize(width: pointWidth, height: pointHeight)
            )
        }

        if let background = options.backgroundColor {
            ctx.setFillColor(background)
            ctx.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        }

        // Bitmap is y-down; flip to math y-up, then place baseline.
        ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
        ctx.scaleBy(x: scale, y: -scale)
        let origin = CGPoint(x: pad, y: pad + display.descent)
        ctx.draw(display, at: origin, foregroundColor: options.foregroundColor, fonts: fonts)

        let image = ctx.makeImage()!
        return Result(
            image: image,
            display: display,
            size: CGSize(width: pointWidth, height: pointHeight)
        )
    }

    public struct DiffStats: Sendable, Equatable {
        public var width: Int
        public var height: Int
        public var differingPixels: Int
        public var maxChannelDelta: UInt8
        public var totalPixels: Int

        public var differingFraction: Double {
            guard totalPixels > 0 else { return 0 }
            return Double(differingPixels) / Double(totalPixels)
        }
    }

    /// Encode a bitmap as PNG.
    public static func pngData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// Decode PNG bytes into a `CGImage`.
    public static func image(fromPNG data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Pixel-wise comparison for golden tests (premultiplied RGBA).
    public static func diff(_ a: CGImage, _ b: CGImage) -> DiffStats? {
        guard a.width == b.width, a.height == b.height else { return nil }
        guard
            let aData = rgbaBytes(of: a),
            let bData = rgbaBytes(of: b),
            aData.count == bData.count
        else {
            return nil
        }

        var differing = 0
        var maxDelta: UInt8 = 0
        let pixels = a.width * a.height
        for i in stride(from: 0, to: aData.count, by: 4) {
            var pixelDelta: UInt8 = 0
            for c in 0..<4 {
                let d = UInt8(abs(Int(aData[i + c]) - Int(bData[i + c])))
                pixelDelta = max(pixelDelta, d)
            }
            if pixelDelta > 0 {
                differing += 1
                maxDelta = max(maxDelta, pixelDelta)
            }
        }
        return DiffStats(
            width: a.width,
            height: a.height,
            differingPixels: differing,
            maxChannelDelta: maxDelta,
            totalPixels: pixels
        )
    }

    /// Whether images match within tolerance (OS font AA can vary slightly).
    public static func matches(
        _ a: CGImage,
        _ b: CGImage,
        maxDifferingFraction: Double = 0.02,
        maxChannelDelta: UInt8 = 12
    ) -> Bool {
        guard let stats = diff(a, b) else { return false }
        if stats.differingPixels == 0 { return true }
        return stats.differingFraction <= maxDifferingFraction && stats.maxChannelDelta <= maxChannelDelta
    }

    /// Stable checksum of premultiplied RGBA bytes (for regression / golden tests).
    public static func checksum(of image: CGImage) -> UInt64 {
        guard let data = rgbaBytes(of: image) else { return 0 }
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325 // FNV-1a 64-bit offset
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 0x100_0000_01b3
        }
        hash ^= UInt64(image.width)
        hash &*= 0x100_0000_01b3
        hash ^= UInt64(image.height)
        hash &*= 0x100_0000_01b3
        return hash
    }

    private static func rgbaBytes(of image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }
}
