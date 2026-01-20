import Foundation
import AppKit
import CoreGraphics

public enum ImageDiffTool {
    /// Default squared color distance threshold.
    /// Uses squared Euclidean distance in RGB space: (r1-r2)² + (g1-g2)² + (b1-b2)²
    /// Default 1600 ≈ perceptual distance of ~40 (e.g., (23,23,23) change in all channels)
    public static let defaultThreshold: Int = 1600

    /// Creates a visual diff between two images.
    /// - Different pixels: highlighted with boosted color from imageB
    /// - Same pixels: dimmed gray with transparency
    /// - threshold: squared Euclidean distance in RGB space (default: 1600)
    public static func createDiff(
        imageA: String,
        imageB: String,
        outputPath: String,
        threshold: Int = defaultThreshold
    ) throws {
        let image1 = try loadImage(from: imageA)
        let image2 = try loadImage(from: imageB)

        let cgImage1 = try cgImage(from: image1, path: imageA)
        let cgImage2 = try cgImage(from: image2, path: imageB)

        let width = cgImage1.width
        let height = cgImage1.height

        guard cgImage2.width == width && cgImage2.height == height else {
            throw DiffError.sizeMismatch(
                image1: (cgImage1.width, cgImage1.height),
                image2: (cgImage2.width, cgImage2.height)
            )
        }

        let data1 = try pixelData(from: cgImage1)
        let data2 = try pixelData(from: cgImage2)

        var resultPixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4

                let r1 = data1[index]
                let g1 = data1[index + 1]
                let b1 = data1[index + 2]
                let a1 = data1[index + 3]

                let r2 = data2[index]
                let g2 = data2[index + 1]
                let b2 = data2[index + 2]
                let a2 = data2[index + 3]

                // Squared Euclidean distance in RGB space (faster than sqrt)
                let dr = Int(r1) - Int(r2)
                let dg = Int(g1) - Int(g2)
                let db = Int(b1) - Int(b2)
                let da = Int(a1) - Int(a2)
                let distanceSquared = dr*dr + dg*dg + db*db + da*da
                let isDifferent = distanceSquared > threshold

                if isDifferent {
                    // Highlight difference: boost color from second image
                    resultPixels[index] = UInt8(min(255, Int(r2) * 2))
                    resultPixels[index + 1] = UInt8(min(255, Int(g2) * 2))
                    resultPixels[index + 2] = UInt8(min(255, Int(b2) * 2))
                    resultPixels[index + 3] = 255
                } else {
                    // Same pixel: dim gray with transparency
                    resultPixels[index] = 100
                    resultPixels[index + 1] = 100
                    resultPixels[index + 2] = 100
                    resultPixels[index + 3] = 100
                }
            }
        }

        let resultImage = try createImage(from: &resultPixels, width: width, height: height)
        try savePNG(image: resultImage, to: outputPath)
    }

    // MARK: - Private

    private static func loadImage(from path: String) throws -> NSImage {
        guard let image = NSImage(contentsOfFile: path) else {
            throw DiffError.failedToLoadImage(path)
        }
        return image
    }

    private static func cgImage(from nsImage: NSImage, path: String) throws -> CGImage {
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw DiffError.failedToConvertToCGImage(path)
        }
        return cgImage
    }

    private static func pixelData(from image: CGImage) throws -> [UInt8] {
        let width = image.width
        let height = image.height
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw DiffError.failedToCreateContext
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelData
    }

    private static func createImage(from pixels: inout [UInt8], width: Int, height: Int) throws -> NSImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let cgImage = context.makeImage() else {
            throw DiffError.failedToCreateResultImage
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    private static func savePNG(image: NSImage, to path: String) throws {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw DiffError.failedToSavePNG(path)
        }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            throw DiffError.failedToSavePNG(path)
        }

        try pngData.write(to: URL(fileURLWithPath: path))
    }
}

// MARK: - Errors

extension ImageDiffTool {
    public enum DiffError: LocalizedError {
        case failedToLoadImage(String)
        case failedToConvertToCGImage(String)
        case failedToCreateContext
        case failedToCreateResultImage
        case failedToSavePNG(String)
        case sizeMismatch(image1: (Int, Int), image2: (Int, Int))

        public var errorDescription: String? {
            switch self {
            case .failedToLoadImage(let path):
                return "Failed to load image: \(path)"
            case .failedToConvertToCGImage(let path):
                return "Failed to convert to CGImage: \(path)"
            case .failedToCreateContext:
                return "Failed to create graphics context"
            case .failedToCreateResultImage:
                return "Failed to create result image"
            case .failedToSavePNG(let path):
                return "Failed to save PNG: \(path)"
            case .sizeMismatch(let s1, let s2):
                return "Image size mismatch: \(s1.0)x\(s1.1) vs \(s2.0)x\(s2.1)"
            }
        }
    }
}
