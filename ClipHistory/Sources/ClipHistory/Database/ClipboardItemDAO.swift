import Foundation
import GRDB

final class ClipboardItemDAO {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - Insert / Update

    @discardableResult
    func upsertByHash(_ item: ClipboardItem) throws -> ClipboardItem {
        try dbQueue.write { db in
            if var existing = try ClipboardItem
                .filter(ClipboardItem.Columns.contentHash == item.contentHash)
                .fetchOne(db)
            {
                existing.createdAt = Date()
                try existing.update(db)
                return existing
            } else {
                var newItem = item
                try newItem.insert(db)
                return newItem
            }
        }
    }

    // MARK: - Fetch

    func fetchAll(searchText: String? = nil) throws -> [ClipboardItem] {
        try dbQueue.read { db in
            var query = ClipboardItem
                .order(
                    ClipboardItem.Columns.pinnedAt == nil,
                    ClipboardItem.Columns.pinnedAt.desc,
                    ClipboardItem.Columns.createdAt.desc
                )

            if let text = searchText, !text.isEmpty {
                query = query.filter(
                    ClipboardItem.Columns.textContent.like("%\(text)%")
                )
            }

            return try query.fetchAll(db)
        }
    }

    func fetchCount() throws -> Int {
        try dbQueue.read { db in
            try ClipboardItem.fetchCount(db)
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
}
