import SwiftUI

struct ClipboardCardView: View {
    let item: ClipboardItem
    var onCopy: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void

    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        HStack(spacing: 10) {
            // Pin indicator line
            if item.pinnedAt != nil {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.primaryBlue)
                    .frame(width: 3)
            }

            // Content
            Button(action: {
                onCopy()
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation {
                        showCopied = false
                    }
                }
            }) {
                HStack {
                    switch item.contentType {
                    case .text:
                        TextCardContent(text: item.textContent ?? "")
                    case .image:
                        ImageCardContent(thumbnailFileName: item.thumbnailFileName)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        RelativeTimeText(date: item.createdAt)
                        if showCopied {
                            Text("Copied!")
                                .font(.caption2)
                                .foregroundColor(Theme.primaryBlue)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            // Action buttons
            if isHovered {
                HStack(spacing: 6) {
                    Button(action: onPin) {
                        Image(systemName: item.pinnedAt != nil ? "pin.fill" : "pin")
                            .font(.system(size: 12))
                            .foregroundColor(item.pinnedAt != nil ? Theme.primaryBlue : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(item.pinnedAt != nil ? "Unpin" : "Pin to top")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered
                    ? Color.primary.opacity(0.06)
                    : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
