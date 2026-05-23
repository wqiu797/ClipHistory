import SwiftUI

struct RelativeTimeText: View {
    let date: Date

    var body: some View {
        Text(relativeTimeString(for: date))
            .font(.caption2)
            .foregroundColor(.secondary)
    }

    private func relativeTimeString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
