import AppKit
import Foundation

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
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        thumbCache.countLimit = 200
    }

    // MARK: - Save

    func saveImage(_ tiffData: Data) -> (imageName: String, thumbName: String)? {
        guard let image = NSImage(data: tiffData) else { return nil }

        let uuid = UUID().uuidString
        let imageName = "\(uuid).png"
        let thumbName = "\(uuid)_thumb.png"

        // Save full image as PNG
        guard let fullImageData = pngData(from: image) else { return nil }
        let imageURL = imagesDir.appendingPathComponent(imageName)
        do {
            try fullImageData.write(to: imageURL)
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }

        // Save thumbnail
        let thumb = resizeImage(image, maxSize: NSSize(width: 200, height: 200))
        guard let thumbPNG = pngData(from: thumb) else { return nil }
        let thumbURL = imagesDir.appendingPathComponent(thumbName)
        do {
            try thumbPNG.write(to: thumbURL)
        } catch {
            print("Failed to save thumbnail: \(error)")
            return nil
        }

        return (imageName, thumbName)
    }

    // MARK: - Load

    func loadImage(fileName: String) -> NSImage? {
        let url = imagesDir.appendingPathComponent(fileName)
        return NSImage(contentsOf: url)
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

    func cleanupOrphanedFiles(activeFiles: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: imagesDir.path) else { return }
        for file in files {
            if !activeFiles.contains(file) {
                try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(file))
            }
        }
    }

    // MARK: - Helpers

    private func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private func resizeImage(_ image: NSImage, maxSize: NSSize) -> NSImage {
        let originalSize = image.size
        guard originalSize.width > maxSize.width || originalSize.height > maxSize.height
        else { return image }

        let ratio = min(
            maxSize.width / originalSize.width,
            maxSize.height / originalSize.height
        )
        let newSize = NSSize(
            width: originalSize.width * ratio,
            height: originalSize.height * ratio
        )

        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()
        return resized
    }
}
