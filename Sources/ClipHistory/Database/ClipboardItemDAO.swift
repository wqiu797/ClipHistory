import Foundation
import GRDB

final class ClipboardItemDAO: Sendable {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - Insert / Update

    /// Returns the stored item with the same hash, refreshing its `createdAt` so it bubbles back to
    /// the top. Returns `nil` when the content has not been seen before.
    func touch(hash: String, at date: Date = Date()) throws -> ClipboardItem? {
        try dbQueue.write { db in
            guard var existing = try ClipboardItem
                .filter(ClipboardItem.Columns.contentHash == hash)
                .fetchOne(db)
            else { return nil }

            existing.createdAt = date
            try existing.update(db)
            return existing
        }
    }

    @discardableResult
    func insert(_ item: ClipboardItem) throws -> ClipboardItem {
        try dbQueue.write { db in
            // `inserted` returns a copy whose `didInsert` callback has set the row id;
            // `PersistableRecord.insert` returns Void and leaves the value untouched.
            try item.inserted(db)
        }
    }

    // MARK: - Fetch

    func fetchAll(searchText: String? = nil, limit: Int? = nil) throws -> [ClipboardItem] {
        try dbQueue.read { db in
            var query = ClipboardItem.order(
                ClipboardItem.Columns.pinnedAt == nil,
                ClipboardItem.Columns.pinnedAt.desc,
                ClipboardItem.Columns.createdAt.desc
            )

            if let text = searchText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                // Escape LIKE wildcards so a search for "50%" or "a_b" behaves literally.
                let pattern = "%\(Self.escapeForLike(text))%"
                query = query.filter(
                    sql: "(textContent LIKE ? ESCAPE '\\' OR sourceAppBundleId LIKE ? ESCAPE '\\')",
                    arguments: [pattern, pattern]
                )
            }

            if let limit {
                query = query.limit(limit)
            }

            return try query.fetchAll(db)
        }
    }

    func fetchCount() throws -> Int {
        try dbQueue.read { db in
            try ClipboardItem.fetchCount(db)
        }
    }

    /// File names of every image and thumbnail still referenced by the database.
    func allImageFileNames() throws -> [String] {
        try dbQueue.read { db in
            try ClipboardItem
                .filter(ClipboardItem.Columns.contentType == ContentType.image)
                .fetchAll(db)
                .flatMap { [$0.imageFileName, $0.thumbnailFileName].compactMap { $0 } }
        }
    }

    /// Deletes the oldest unpinned items until the history fits within `maxItems`.
    /// Pinned items are never trimmed.
    func trim(maxItems: Int) throws -> [ClipboardItem] {
        try dbQueue.write { db in
            let total = try ClipboardItem.fetchCount(db)
            guard total > maxItems else { return [] }

            let excess = total - maxItems
            let expired = try ClipboardItem
                .filter(ClipboardItem.Columns.pinnedAt == nil)
                .order(ClipboardItem.Columns.createdAt.asc)
                .limit(excess)
                .fetchAll(db)

            let ids = expired.compactMap(\.id)
            guard !ids.isEmpty else { return [] }

            try ClipboardItem.filter(keys: ids).deleteAll(db)
            return expired
        }
    }

    // MARK: - Pin

    func togglePin(id: Int64) throws {
        try dbQueue.write { db in
            if var item = try ClipboardItem.fetchOne(db, key: id) {
                item.pinnedAt = item.pinnedAt == nil ? Date() : nil
                try item.update(db)
            }
        }
    }

    // MARK: - Delete

    func delete(id: Int64) throws -> ClipboardItem? {
        try dbQueue.write { db in
            let item = try ClipboardItem.fetchOne(db, key: id)
            try ClipboardItem.deleteOne(db, key: id)
            return item
        }
    }

    // MARK: - Cleanup

    func deleteExpired(before cutoff: Date) throws -> [ClipboardItem] {
        try dbQueue.write { db in
            let expired = try ClipboardItem
                .filter(ClipboardItem.Columns.pinnedAt == nil)
                .filter(ClipboardItem.Columns.createdAt < cutoff)
                .fetchAll(db)

            try ClipboardItem
                .filter(ClipboardItem.Columns.pinnedAt == nil)
                .filter(ClipboardItem.Columns.createdAt < cutoff)
                .deleteAll(db)

            return expired
        }
    }

    // MARK: - Helpers

    private static func escapeForLike(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}
