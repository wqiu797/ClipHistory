import Foundation
import GRDB
import XCTest

@testable import ClipHistory

final class ClipboardItemDAOTests: XCTestCase {
    private var dbQueue: DatabaseQueue!
    private var dao: ClipboardItemDAO!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dbQueue = try DatabaseQueue()
        try AppDatabase.migrator.migrate(dbQueue)
        dao = ClipboardItemDAO(dbQueue: dbQueue)
    }

    override func tearDownWithError() throws {
        dao = nil
        dbQueue = nil
        try super.tearDownWithError()
    }

    // MARK: - Insert / update

    func testInsertAssignsIdentifierAndPersistsContent() throws {
        let inserted = try dao.insert(makeText("hello"))

        XCTAssertNotNil(inserted.id)
        XCTAssertEqual(try dao.fetchCount(), 1)

        let fetched = try XCTUnwrap(try dao.fetchAll().first)
        XCTAssertEqual(fetched.id, inserted.id)
        XCTAssertEqual(fetched.textContent, "hello")
        XCTAssertEqual(fetched.contentType, .text)
        XCTAssertEqual(fetched.sourceAppBundleId, "com.example.tests")
    }

    func testTouchRefreshesExistingItem() throws {
        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
        let touchedDate = originalDate.addingTimeInterval(120)
        let inserted = try dao.insert(makeText("hello", hash: "same", createdAt: originalDate))

        XCTAssertNil(try dao.touch(hash: "missing"))

        let touched = try XCTUnwrap(try dao.touch(hash: "same", at: touchedDate))
        XCTAssertEqual(touched.id, inserted.id)
        XCTAssertEqual(
            touched.createdAt.timeIntervalSince1970,
            touchedDate.timeIntervalSince1970,
            accuracy: 0.001
        )
        XCTAssertEqual(try dao.fetchCount(), 1)
    }

    // MARK: - Search

    func testSearchEscapesLikeWildcards() throws {
        for text in ["50% off", "50 percent", "a_b", "axb", "100%"] {
            try dao.insert(makeText(text))
        }

        XCTAssertEqual(
            try dao.fetchAll(searchText: "50%").compactMap(\.textContent),
            ["50% off"]
        )
        XCTAssertEqual(
            try dao.fetchAll(searchText: "a_b").compactMap(\.textContent),
            ["a_b"]
        )
        XCTAssertEqual(
            try dao.fetchAll(searchText: "100%").compactMap(\.textContent),
            ["100%"]
        )
        XCTAssertEqual(
            Set(try dao.fetchAll(searchText: "50").compactMap(\.textContent)),
            ["50% off", "50 percent"]
        )
    }

    // MARK: - Ordering

    func testPinnedItemsSortFirst() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let oldest = try dao.insert(makeText("oldest", hash: "a", createdAt: base))
        _ = try dao.insert(makeText("middle", hash: "b", createdAt: base.addingTimeInterval(60)))
        _ = try dao.insert(makeText("newest", hash: "c", createdAt: base.addingTimeInterval(120)))

        try dao.togglePin(id: XCTUnwrap(oldest.id))

        XCTAssertEqual(
            try dao.fetchAll().compactMap(\.textContent),
            ["oldest", "newest", "middle"]
        )
    }

    func testFetchAllHonoursLimit() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for index in 0..<5 {
            try dao.insert(makeText(
                "item-\(index)",
                createdAt: base.addingTimeInterval(TimeInterval(index))
            ))
        }

        let limited = try dao.fetchAll(limit: 2)
        XCTAssertEqual(limited.compactMap(\.textContent), ["item-4", "item-3"])
    }

    // MARK: - Deletion

    func testDeleteReturnsRemovedItem() throws {
        let item = try dao.insert(makeText("gone", hash: "g"))
        let deleted = try dao.delete(id: try XCTUnwrap(item.id))

        XCTAssertEqual(deleted?.textContent, "gone")
        XCTAssertEqual(try dao.fetchCount(), 0)
        XCTAssertNil(try dao.delete(id: try XCTUnwrap(item.id)))
    }

    func testDeleteExpiredKeepsPinnedItems() throws {
        let now = Date()
        let oldDate = now.addingTimeInterval(-10 * 86400)
        let cutoff = now.addingTimeInterval(-5 * 86400)

        let expired = try dao.insert(makeText("expired", hash: "e", createdAt: oldDate))
        let pinned = try dao.insert(makeText("pinned", hash: "p", createdAt: oldDate, pinnedAt: now))
        let recent = try dao.insert(makeText("recent", hash: "r", createdAt: now))

        let deleted = try dao.deleteExpired(before: cutoff)

        XCTAssertEqual(deleted.compactMap(\.id), [expired.id].compactMap { $0 })
        XCTAssertEqual(try dao.fetchCount(), 2)

        let remaining = Set(try dao.fetchAll().compactMap(\.id))
        XCTAssertEqual(remaining, Set([pinned.id, recent.id].compactMap { $0 }))
    }

    func testSearchMatchesSourceAppAndImageItems() throws {
        try dao.insert(makeText("browser tab", hash: "safari", sourceApp: "com.apple.Safari"))
        try dao.insert(makeText("other", hash: "other", sourceApp: "com.example.Other"))
        try dao.insert(ClipboardItem(
            contentType: .image,
            imageFileName: "preview.png",
            thumbnailFileName: "preview_thumb.png",
            sourceAppBundleId: "com.apple.Preview",
            createdAt: Date(),
            contentHash: "preview"
        ))

        XCTAssertEqual(
            try dao.fetchAll(searchText: "safari").compactMap(\.textContent),
            ["browser tab"]
        )
        XCTAssertEqual(
            try dao.fetchAll(searchText: "preview").compactMap(\.contentType),
            [.image]
        )
    }

    func testTrimKeepsNewestUnpinnedItems() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try dao.insert(makeText("pinned", hash: "pinned", createdAt: base, pinnedAt: base))
        _ = try dao.insert(makeText("old", hash: "old", createdAt: base.addingTimeInterval(1)))
        _ = try dao.insert(makeText("older", hash: "older", createdAt: base.addingTimeInterval(2)))
        _ = try dao.insert(makeText("oldest-kept", hash: "oldest-kept", createdAt: base.addingTimeInterval(3)))
        _ = try dao.insert(makeText("newest", hash: "newest", createdAt: base.addingTimeInterval(4)))

        let removed = try dao.trim(maxItems: 3)

        XCTAssertEqual(Set(removed.compactMap(\.textContent)), ["old", "older"])
        XCTAssertEqual(
            Set(try dao.fetchAll().compactMap(\.textContent)),
            ["pinned", "oldest-kept", "newest"]
        )
    }

    // MARK: - Images

    func testAllImageFileNamesReturnsReferencedFiles() throws {
        try dao.insert(ClipboardItem(
            contentType: .image,
            imageFileName: "full.png",
            thumbnailFileName: "thumb.png",
            createdAt: Date(),
            contentHash: "image"
        ))
        try dao.insert(makeText("plain text"))

        XCTAssertEqual(
            Set(try dao.allImageFileNames()),
            ["full.png", "thumb.png"]
        )
    }

    // MARK: - Helpers

    private func makeText(
        _ text: String,
        hash: String? = nil,
        createdAt: Date = Date(),
        pinnedAt: Date? = nil,
        sourceApp: String = "com.example.tests"
    ) -> ClipboardItem {
        ClipboardItem(
            contentType: .text,
            textContent: text,
            sourceAppBundleId: sourceApp,
            pinnedAt: pinnedAt,
            createdAt: createdAt,
            contentHash: hash ?? "hash-\(UUID().uuidString)"
        )
    }
}
