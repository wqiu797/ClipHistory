import os

/// Centralised loggers so messages can be filtered with `log show --predicate 'subsystem == "com.cliphistory.app"'`.
enum Log {
    private static let subsystem = "com.cliphistory.app"

    static let database = Logger(subsystem: subsystem, category: "database")
    static let clipboard = Logger(subsystem: subsystem, category: "clipboard")
    static let images = Logger(subsystem: subsystem, category: "images")
    static let cleanup = Logger(subsystem: subsystem, category: "cleanup")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
