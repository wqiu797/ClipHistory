import SwiftUI

struct TextCardContent: View {
    let text: String

    var body: some View {
        Text(displayText)
            .font(.system(size: 12))
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 200 {
            return String(trimmed.prefix(200)) + "..."
        }
        return trimmed
    }
}
