import Foundation
import GRDB

struct ClipboardItem: Codable, Identifiable, Equatable {
    var id: Int64?
    var contentType: ContentType
    var textContent: String?
    var imageFileName: String?
    var thumbnailFileName: String?
    var sourceAppBundleId: String?
    var pinnedAt: Date?
    var createdAt: Date
    var contentHash: String

    static let databaseTableName = "clipboard_item"

    enum Columns: String, ColumnExpression {
        case id, contentType, textContent, imageFileName
        case thumbnailFileName, sourceAppBundleId, pinnedAt
        case createdAt, contentHash
    }
}

extension ClipboardItem: TableRecord, FetchableRecord, PersistableRecord {
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
