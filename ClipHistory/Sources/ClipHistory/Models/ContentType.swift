import GRDB

enum ContentType: String, Codable, DatabaseValueConvertible, Sendable {
    case text
    case image
}
