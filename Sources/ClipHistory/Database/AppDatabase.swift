import Foundation
import GRDB

final class AppDatabase: Sendable {
    static let shared = AppDatabase()

    let dbQueue: DatabaseQueue

    /// Injection point for tests / tools that need an isolated database.
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let dbDirectory = appSupport.appendingPathComponent("ClipHistory", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: dbDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            Log.database.fault(
                "Could not create Application Support directory: \(String(describing: error), privacy: .public)"
            )
        }
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: dbDirectory.path
        )

        let dbURL = dbDirectory.appendingPathComponent("cliphistory.sqlite")
        dbQueue = Self.openRecovering(at: dbURL)
        Self.restrictDatabasePermissions(at: dbURL)
    }

    /// Clipboard history is sensitive: keep the database and its WAL files readable only by the
    /// current user. The enclosing directory is also 0700, so future WAL files stay protected.
    private static func restrictDatabasePermissions(at url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            let path = url.path + suffix
            guard FileManager.default.fileExists(atPath: path) else { continue }
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: path
            )
        }
    }

    // MARK: - Opening

    /// Opens the database, migrating it if necessary. A damaged database is moved aside and
    /// recreated instead of crashing the app on launch.
    private static func openRecovering(at url: URL) -> DatabaseQueue {
        do {
            let queue = try DatabaseQueue(path: url.path)
            try migrator.migrate(queue)
            return queue
        } catch {
            Log.database.error(
                "Could not open database at \(url.path, privacy: .public): \(String(describing: error), privacy: .public)"
            )
        }

        quarantine(url)

        do {
            let queue = try DatabaseQueue(path: url.path)
            try migrator.migrate(queue)
            Log.database.notice("Recreated database after moving the damaged file aside")
            return queue
        } catch {
            Log.database.fault(
                "Could not recreate database: \(String(describing: error), privacy: .public)"
            )
        }

        // Last resort: keep the app usable, even if history cannot be persisted.
        if let memory = try? DatabaseQueue(), (try? migrator.migrate(memory)) != nil {
            Log.database.fault("Falling back to an in-memory database; history will not be persisted")
            return memory
        }

        fatalError("ClipHistory could not create a usable database")
    }

    /// Moves a damaged database (and its WAL sidecar files) out of the way so a fresh one can be created.
    private static func quarantine(_ url: URL) {
        let fileManager = FileManager.default
        let stamp = String(Int(Date().timeIntervalSince1970))
        let baseName = url.lastPathComponent

        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: url.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }

            let destination = url
                .deletingLastPathComponent()
                .appendingPathComponent("\(baseName).corrupt-\(stamp)\(suffix)")
            do {
                try fileManager.moveItem(at: source, to: destination)
                Log.database.notice("Moved damaged database file to \(destination.lastPathComponent, privacy: .public)")
            } catch {
                Log.database.error(
                    "Could not move \(source.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)"
                )
            }
        }
    }

    // MARK: - Schema

    /// Internal rather than private so tests can migrate an in-memory database.
    static var migrator: DatabaseMigrator {
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
