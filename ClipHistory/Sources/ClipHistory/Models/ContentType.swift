import GRDB

enum ContentType: String, Codable, DatabaseValueConvertible {
    case text
    case image
}
