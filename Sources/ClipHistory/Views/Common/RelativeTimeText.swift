import SwiftUI

struct RelativeTimeText: View {
    let date: Date

    @MainActor
    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        Text(Self.formatter.localizedString(for: date, relativeTo: Date()))
            .font(.caption2)
            .foregroundColor(.secondary)
    }
}
