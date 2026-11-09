import SwiftUI

struct ClipboardCardView: View {
    let item: ClipboardItem
    var isSelected: Bool = false
    var onCopy: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void

    @State private var isHovered = false
    @State private var showCopied = false
    @State private var copyToken = 0

    var body: some View {
        HStack(spacing: 10) {
            // Pin indicator line
            if item.pinnedAt != nil {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.primaryBlue)
                    .frame(width: 3)
            }

            // Content
            Button {
                copyToken += 1
                onCopy()
            } label: {
                HStack(spacing: 8) {
                    content

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            SourceAppIcon(bundleIdentifier: item.sourceAppBundleId)
                            RelativeTimeText(date: item.createdAt)
                        }

                        if showCopied {
                            Text("Copied!")
                                .font(.caption2)
                                .foregroundColor(Theme.primaryBlue)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .help(item.contentType == .text ? "Copy to clipboard" : "Copy image to clipboard")

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
                    .accessibilityLabel(item.pinnedAt != nil ? "Unpin" : "Pin to top")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                    .accessibilityLabel("Delete")
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        // `.task(id:)` cancels itself when the card is recycled, so the "Copied!" badge can never
        // leak onto a different row.
        .task(id: copyToken) {
            guard copyToken > 0 else { return }
            showCopied = true
            try? await Task.sleep(for: .milliseconds(800))
            if !Task.isCancelled {
                showCopied = false
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.contentType {
        case .text:
            TextCardContent(text: item.textContent ?? "")
        case .image:
            ImageCardContent(thumbnailFileName: item.thumbnailFileName)
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Theme.primaryBlue.opacity(0.16)
        }
        return isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03)
    }

    private var borderColor: Color {
        isSelected ? Theme.primaryBlue.opacity(0.6) : Color.primary.opacity(0.08)
    }
}
