import AppKit
import CryptoKit
import Foundation

final class ClipboardMonitor: @unchecked Sendable {
    static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var ownWriteChangeCount: Int = -1
    private let dao = ClipboardItemDAO()
    private let imageStore = ImageStore.shared

    var onNewItem: ((ClipboardItem) -> Void)?

    private init() {}

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call this before writing to the pasteboard to avoid re-capturing our own writes
    func markOwnWrite() {
        ownWriteChangeCount = NSPasteboard.general.changeCount
    }

    private func poll() {
        let pb = NSPasteboard.general
        let currentCount = pb.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // Skip changes we caused
        if currentCount == ownWriteChangeCount {
            ownWriteChangeCount = -1
            return
        }

        if let text = pb.string(forType: .string), !text.isEmpty {
            captureText(text)
        } else if let image = pb.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
                  let tiffData = image.tiffRepresentation
        {
            captureImage(tiffData: tiffData, image: image)
        }
    }

    private func captureText(_ text: String) {
        let hash = SHA256.hash(data: Data(text.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        var item = ClipboardItem(
            contentType: .text,
            textContent: text,
            sourceAppBundleId: sourceApp,
            createdAt: Date(),
            contentHash: hash
        )

        do {
            let saved = try dao.upsertByHash(item)
            DispatchQueue.main.async { [weak self] in
                self?.onNewItem?(saved)
            }
        } catch {
            print("Failed to save text clipboard: \(error)")
        }
    }

    private func captureImage(tiffData: Data, image: NSImage) {
        let hash = SHA256.hash(data: tiffData).compactMap { String(format: "%02x", $0) }.joined()
        let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        guard let (imageName, thumbName) = imageStore.saveImage(tiffData) else {
            return
        }

        var item = ClipboardItem(
            contentType: .image,
            imageFileName: imageName,
            thumbnailFileName: thumbName,
            sourceAppBundleId: sourceApp,
            createdAt: Date(),
            contentHash: hash
        )

        do {
            let saved = try dao.upsertByHash(item)
            DispatchQueue.main.async { [weak self] in
                self?.onNewItem?(saved)
            }
        } catch {
            print("Failed to save image clipboard: \(error)")
        }
    }
}
