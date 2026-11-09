enum HistoryLimits {
    /// Keep the history bounded so the full list stays cheap to load and search.
    static let maxItems = 500
    /// Very large text (logs, dumps) is skipped rather than bloating the database.
    static let maxTextBytes = 2_000_000
}
