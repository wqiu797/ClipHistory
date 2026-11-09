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
        ZStack(alignment: .topTrailing) {
            // The whole card - including its padding - is the copy button, so short
            // text and image items stay clickable across the empty space.
            Button {
                copyItem()
            } label: {
                HStack(spacing: 10) {
                    // Pin indicator line
                    if item.pinnedAt != nil {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.primaryBlue)
                            .frame(width: 3)
                    }

                    content

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            SourceAppIcon(bundleIdentifier: item.sourceAppBundleId)
                            RelativeTimeText(date: item.createdAt)
                        }
                        // The action buttons take this spot on hover, so there is no
                        // layout shift when they appear.
                        .opacity(isHovered ? 0 : 1)

                        if showCopied {
                            Text("Copied!")
                                .font(.caption2)
                                .foregroundColor(Theme.primaryBlue)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help(item.contentType == .text ? "Copy to clipboard" : "Copy image to clipboard")

            // Action buttons are siblings of the button, so their clicks win over
            // the copy action while the rest of the card still copies.
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
                .padding(.top, 8)
                .padding(.trailing, 10)
                .transition(.opacity)
                .allowsHitTesting(isHovered)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
                .allowsHitTesting(false)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button("Copy") {
                copyItem()
            }
            Button(item.pinnedAt != nil ? "Unpin" : "Pin to Top") {
                onPin()
            }
            Divider()
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
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

    private func copyItem() {
        copyToken += 1
        onCopy()
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
