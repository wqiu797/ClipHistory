import AppKit
import CryptoKit
import Foundation
import ImageIO

/// A clipboard image that has been decoded and normalised to PNG, but not written to disk yet.
struct EncodedImage: Sendable {
    let pngData: Data
    let thumbnailPNGData: Data
    let contentHash: String
}

final class ImageStore: @unchecked Sendable {
    static let shared = ImageStore()

    private let imagesDir: URL
    private let thumbCache = NSCache<NSString, NSImage>()

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        imagesDir = appSupport
            .appendingPathComponent("ClipHistory")
            .appendingPathComponent("Images")
        try? FileManager.default.createDirectory(
            at: imagesDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: imagesDir.path
        )
        thumbCache.countLimit = 200
    }

    // MARK: - Encode

    /// Normalises arbitrary clipboard image data (PNG/TIFF/…) into a full-size PNG, a thumbnail and
    /// a stable hash. Hashing the canonical PNG keeps deduplication reliable across the different
    /// TIFF representations apps put on the pasteboard.
    func encode(_ imageData: Data) -> EncodedImage? {
        guard let image = NSImage(data: imageData),
              let fullPNG = pngData(from: image)
        else {
            Log.images.error("Could not decode clipboard image")
            return nil
        }

        let thumbnailPNG = downsampledPNG(from: fullPNG, maxPixelSize: 400) ?? fullPNG
        let hash = SHA256.hash(data: fullPNG)
            .map { String(format: "%02x", $0) }
            .joined()

        return EncodedImage(
            pngData: fullPNG,
            thumbnailPNGData: thumbnailPNG,
            contentHash: hash
        )
    }

    // MARK: - Write

    /// Persists an encoded image. Rolls back partial writes so a failure never leaves half an image
    /// on disk.
    func write(_ encoded: EncodedImage) -> (imageName: String, thumbnailName: String)? {
        let identifier = UUID().uuidString
        let imageName = "\(identifier).png"
        let thumbnailName = "\(identifier)_thumb.png"
        let imageURL = imagesDir.appendingPathComponent(imageName)
        let thumbnailURL = imagesDir.appendingPathComponent(thumbnailName)

        do {
            try encoded.pngData.write(to: imageURL, options: .atomic)
            try encoded.thumbnailPNGData.write(to: thumbnailURL, options: .atomic)
            Self.restrictPermissions(of: imageURL)
            Self.restrictPermissions(of: thumbnailURL)
        } catch {
            Log.images.error("Could not write image files: \(String(describing: error), privacy: .public)")
            try? FileManager.default.removeItem(at: imageURL)
            try? FileManager.default.removeItem(at: thumbnailURL)
            return nil
        }

        return (imageName, thumbnailName)
    }

    // MARK: - Load

    func loadPNGData(fileName: String) -> Data? {
        try? Data(contentsOf: imagesDir.appendingPathComponent(fileName))
    }

    func loadImage(fileName: String) -> NSImage? {
        NSImage(contentsOf: imagesDir.appendingPathComponent(fileName))
    }

    func loadThumbnail(fileName: String) -> NSImage? {
        if let cached = thumbCache.object(forKey: fileName as NSString) {
            return cached
        }
        let url = imagesDir.appendingPathComponent(fileName)
        guard let image = NSImage(contentsOf: url) else { return nil }
        thumbCache.setObject(image, forKey: fileName as NSString)
        return image
    }

    // MARK: - Delete

    func deleteImages(imageName: String?, thumbName: String?) {
        if let name = imageName {
            try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(name))
        }
        if let name = thumbName {
            thumbCache.removeObject(forKey: name as NSString)
            try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(name))
        }
    }

    /// Deletes image files that no database row references. Files younger than `minimumAge` are kept
    /// so a capture that is still being saved is never swept away.
    func cleanupOrphanedFiles(activeFiles: Set<String>, minimumAge: TimeInterval = 60 * 60) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: imagesDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-minimumAge)
        var removed = 0

        for url in urls where !activeFiles.contains(url.lastPathComponent) {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            guard modified < cutoff else { continue }
            if (try? FileManager.default.removeItem(at: url)) != nil {
                removed += 1
            }
        }

        if removed > 0 {
            Log.images.notice("Removed \(removed) orphaned image files")
        }
    }

    // MARK: - Permissions

    private static func restrictPermissions(of url: URL) {
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    // MARK: - Helpers

    private func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    /// Downscales through ImageIO so it can run off the main thread without touching `lockFocus`.
    private func downsampledPNG(from data: Data, maxPixelSize: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    }
}
