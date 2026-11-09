import AppKit
import SwiftUI

struct PopoverRootView: View {
    @State private var viewModel = ClipboardViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                SearchBar(text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.setSearchText($0) }
                ))
                .frame(maxWidth: .infinity)

                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Card list
            if viewModel.items.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No clipboard history yet")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Text("Copy something and it will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.items) { item in
                            ClipboardCardView(
                                item: item,
                                onCopy: { viewModel.copyToClipboard(item) },
                                onPin: { viewModel.togglePin(item) },
                                onDelete: { viewModel.delete(item) }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }

            Divider()

            // Footer
            HStack {
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit ClipHistory")

                Text("\(viewModel.itemCount) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Keeping \(viewModel.retentionDays) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 380, height: 520)
    }

    private func openSettings() {
        SettingsWindowController.shared.show()
    }
}
