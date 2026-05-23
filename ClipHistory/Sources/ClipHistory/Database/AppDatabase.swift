import Foundation
import GRDB

final class AppDatabase: @unchecked Sendable {
    static let shared = AppDatabase()

    let dbQueue: DatabaseQueue

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let dbDir = appSupport.appendingPathComponent("ClipHistory")
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)

        let dbPath = dbDir.appendingPathComponent("cliphistory.sqlite").path
        dbQueue = try! DatabaseQueue(path: dbPath)

        try! migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: ClipboardItem.databaseTableName) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("contentType", .text).notNull()
                t.column("textContent", .text)
                t.column("imageFileName", .text)
                t.column("thumbnailFileName", .text)
                t.column("sourceAppBundleId", .text)
                t.column("pinnedAt", .datetime)
                t.column("createdAt", .datetime).notNull()
                t.column("contentHash", .text).notNull()
            }
            try db.create(
                index: "idx_clipboard_item_createdAt",
                on: ClipboardItem.databaseTableName,
                columns: ["createdAt"]
            )
            try db.create(
                index: "idx_clipboard_item_contentHash",
                on: ClipboardItem.databaseTableName,
                columns: ["contentHash"]
            )
        }

        migrator.registerMigration("v2") { db in
            try db.create(
                index: "idx_clipboard_item_pinnedAt",
                on: ClipboardItem.databaseTableName,
                columns: ["pinnedAt"]
            )
        }

        return migrator
    }
}
