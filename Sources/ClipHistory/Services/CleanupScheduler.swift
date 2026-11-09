import Foundation

final class CleanupScheduler: @unchecked Sendable {
    static let shared = CleanupScheduler()

    private let dao = ClipboardItemDAO()
    private let imageStore = ImageStore.shared
    private var timer: Timer?

    private init() {}

    func start() {
        // Run on start
        performCleanup()
        // Schedule daily cleanup
        timer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func performCleanup() {
        let days = Preferences.retentionDays

        guard let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -days,
            to: Date()
        ) else { return }

        let dao = self.dao
        let imageStore = self.imageStore

        // Deletion touches the disk, so keep it off the main thread.
        DispatchQueue.global(qos: .utility).async {
            do {
                let expired = try dao.deleteExpired(before: cutoff)
                let trimmed = try dao.trim(maxItems: HistoryLimits.maxItems)
                for item in expired + trimmed where item.contentType == .image {
                    imageStore.deleteImages(
                        imageName: item.imageFileName,
                        thumbName: item.thumbnailFileName
                    )
                }
                if !expired.isEmpty {
                    Log.cleanup.notice("Removed \(expired.count) expired clipboard items")
                }
                if !trimmed.isEmpty {
                    Log.cleanup.notice("Trimmed \(trimmed.count) items over the history limit")
                }
            } catch {
                Log.cleanup.error("Cleanup failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
