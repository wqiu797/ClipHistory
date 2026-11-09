import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ClipboardViewModel {
    private let dao = ClipboardItemDAO()
    private let imageStore = ImageStore.shared
    private let monitor = ClipboardMonitor.shared

    var items: [ClipboardItem] = []
    var searchText = ""
    var itemCount: Int = 0
    var retentionDays: Int = 3

    private var searchTask: Task<Void, Never>?
    private var loadGeneration = 0
    private var defaultsObserver: NSObjectProtocol?

    init() {
        retentionDays = Self.currentRetentionDays()
        loadItems()

        monitor.onNewItem = { [weak self] _ in
            Task { @MainActor in
                self?.loadItems()
            }
        }

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadItems()
            }
        }
    }

    // The view model lives as long as the popover; the weak observer closure needs no teardown.

    // MARK: - Loading

    /// Reads the database on a background task so scrolling and typing never wait on SQLite.
    func loadItems() {
        loadGeneration += 1
        let generation = loadGeneration
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let dao = self.dao

        Task.detached(priority: .userInitiated) { [self] in
            do {
                let items = try dao.fetchAll(searchText: query.isEmpty ? nil : query)
                let count = try dao.fetchCount()

                await MainActor.run {
                    guard loadGeneration == generation else { return }
                    self.items = items
                    self.itemCount = count
                    self.retentionDays = Self.currentRetentionDays()
                }
            } catch {
                Log.database.error(
                    "Failed to load items: \(String(describing: error), privacy: .public)"
                )
            }
        }
    }

    /// Updates the query immediately (so the search field state stays in sync) and debounces the
    /// database round-trip.
    func setSearchText(_ text: String) {
        guard text != searchText else { return }
        searchText = text
        searchTask?.cancel()

        guard !text.isEmpty else {
            loadItems()
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let self else { return }
            self.loadItems()
        }
    }

    // MARK: - Actions

    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.contentType {
        case .text:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let fileName = item.imageFileName,
               let image = imageStore.loadImage(fileName: fileName)
            {
                pasteboard.writeObjects([image])
            }
        }

        // Must come after writing, otherwise the monitor captures our own write.
        monitor.markOwnWrite()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let id = item.id else { return }
        let dao = self.dao

        Task.detached(priority: .userInitiated) { [self] in
            do {
                try dao.togglePin(id: id)
            } catch {
                Log.database.error(
                    "Failed to toggle pin: \(String(describing: error), privacy: .public)"
                )
            }
            await MainActor.run {
                self.loadItems()
            }
        }
    }

    func delete(_ item: ClipboardItem) {
        guard let id = item.id else { return }
        let dao = self.dao
        let imageStore = self.imageStore

        Task.detached(priority: .userInitiated) { [self] in
            do {
                if let deleted = try dao.delete(id: id), deleted.contentType == .image {
                    imageStore.deleteImages(
                        imageName: deleted.imageFileName,
                        thumbName: deleted.thumbnailFileName
                    )
                }
            } catch {
                Log.database.error(
                    "Failed to delete item: \(String(describing: error), privacy: .public)"
                )
            }
            await MainActor.run {
                self.loadItems()
            }
        }
    }

    // MARK: - Preferences

    static func currentRetentionDays() -> Int {
        let days = UserDefaults.standard.integer(forKey: "retentionDays")
        return days > 0 ? days : 3
    }
}
