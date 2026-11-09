import Foundation

extension Notification.Name {
    /// Posted after history was deleted outside the view model (e.g. from the menu bar).
    static let clipboardHistoryDidChange = Notification.Name("ClipHistory.historyDidChange")
}

/// Maintenance operations that must work without a live popover.
final class HistoryMaintenance: @unchecked Sendable {
    static let shared = HistoryMaintenance()

    private let dao = ClipboardItemDAO()
    private let imageStore = ImageStore.shared

    private init() {}

    /// Deletes every row and its image files, then tells observers to reload.
    func clearAll() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let deleted = try self.dao.deleteAll()
                for item in deleted where item.contentType == .image {
                    self.imageStore.deleteImages(
                        imageName: item.imageFileName,
                        thumbName: item.thumbnailFileName
                    )
                }
                NotificationCenter.default.post(name: .clipboardHistoryDidChange, object: nil)
                Log.database.notice("Cleared \(deleted.count) clipboard items")
            } catch {
                Log.database.error(
                    "Failed to clear history: \(String(describing: error), privacy: .public)"
                )
            }
        }
    }
}
