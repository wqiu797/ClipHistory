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

    init() {
        retentionDays = UserDefaults.standard.integer(forKey: "retentionDays")
        if retentionDays == 0 { retentionDays = 3 }

        loadItems()

        monitor.onNewItem = { [weak self] _ in
            Task { @MainActor in
                self?.loadItems()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    func loadItems() {
        do {
            items = try dao.fetchAll(searchText: searchText.isEmpty ? nil : searchText)
            itemCount = try dao.fetchCount()
            retentionDays = UserDefaults.standard.integer(forKey: "retentionDays")
            if retentionDays == 0 { retentionDays = 3 }
        } catch {
            print("Failed to load items: \(error)")
        }
    }

    func search(_ text: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            searchText = text
            loadItems()
        }
    }

    func copyToClipboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()

        switch item.contentType {
        case .text:
            if let text = item.textContent {
                pb.setString(text, forType: .string)
            }
        case .image:
            if let fileName = item.imageFileName,
               let image = imageStore.loadImage(fileName: fileName)
            {
                pb.writeObjects([image])
            }
        }

        monitor.markOwnWrite()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let id = item.id else { return }
        do {
            try dao.togglePin(id: id)
            loadItems()
        } catch {
            print("Failed to toggle pin: \(error)")
        }
    }

    func delete(_ item: ClipboardItem) {
        guard let id = item.id else { return }
        do {
            if let deleted = try dao.delete(id: id),
               deleted.contentType == .image
            {
                imageStore.deleteImages(
                    imageName: deleted.imageFileName,
                    thumbName: deleted.thumbnailFileName
                )
            }
            loadItems()
        } catch {
            print("Failed to delete item: \(error)")
        }
    }

    @objc private func settingsChanged() {
        loadItems()
    }
}
