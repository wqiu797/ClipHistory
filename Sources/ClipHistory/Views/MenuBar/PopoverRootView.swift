import AppKit
import Combine
import SwiftUI

struct PopoverRootView: View {
    @State private var viewModel = ClipboardViewModel()
    @State private var selectedItemID: Int64?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            historyList
            Divider()
            footer
        }
        .frame(width: 380, height: 520)
        .background(KeyEventHandler(onKeyDown: handleKeyDown))
        .onReceive(NotificationCenter.default.publisher(for: NSPopover.didShowNotification)) { _ in
            selectedItemID = nil
            viewModel.loadItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSPopover.didCloseNotification)) { _ in
            selectedItemID = nil
            if !viewModel.searchText.isEmpty {
                viewModel.setSearchText("")
            }
        }
        .onChange(of: viewModel.searchText) { _, _ in
            selectedItemID = nil
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            SearchBar(text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.setSearchText($0) }
            ))
            .frame(maxWidth: .infinity)

            Button {
                viewModel.togglePause()
            } label: {
                Image(systemName: viewModel.isPaused ? "play.circle" : "pause.circle")
                    .font(.system(size: 14))
                    .foregroundColor(viewModel.isPaused ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .help(viewModel.isPaused ? "Resume recording" : "Pause recording")
            .accessibilityLabel(viewModel.isPaused ? "Resume recording" : "Pause recording")

            Button {
                SettingsWindowController.shared.show()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var historyList: some View {
        VStack(spacing: 0) {
            if viewModel.items.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(viewModel.searchText.isEmpty ? "No clipboard history yet" : "No matching items")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Text(viewModel.searchText.isEmpty
                         ? "Copy something and it will appear here"
                         : "Try a different search term")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(viewModel.items) { item in
                                ClipboardCardView(
                                    item: item,
                                    isSelected: item.id == selectedItemID,
                                    onCopy: {
                                        selectedItemID = item.id
                                        viewModel.copyToClipboard(item)
                                    },
                                    onPin: { viewModel.togglePin(item) },
                                    onDelete: { viewModel.delete(item) }
                                )
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: selectedItemID) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit ClipHistory")
            .accessibilityLabel("Quit ClipHistory")

            Text("\(viewModel.itemCount) items")
                .font(.caption)
                .foregroundColor(.secondary)

            if viewModel.isPaused {
                Text("Paused")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Spacer()

            if !viewModel.isStoragePersistent {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .help("History is not being saved. Check disk access and relaunch ClipHistory.")
            }

            Text("↑↓ ⏎ esc")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
                .help("Arrow keys select · Return copies · Esc closes")

            Spacer()

            Text("Keep \(viewModel.retentionDays)d")
                .font(.caption)
                .foregroundColor(.secondary)
                .help("Clipboard history is kept for \(viewModel.retentionDays) days")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Keyboard

    private var selectedIndex: Int? {
        guard let selectedItemID else { return nil }
        return viewModel.items.firstIndex { $0.id == selectedItemID }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        // Never steal keys from an active input-method composition (e.g. Pinyin).
        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.hasMarkedText() {
            return false
        }

        // Caps Lock and the function/numeric-pad flags must not disable navigation.
        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function, .shift])

        if flags.contains(.command),
           let characters = event.charactersIgnoringModifiers,
           let number = Int(characters),
           (1...9).contains(number)
        {
            copyItem(at: number - 1)
            return true
        }

        guard flags.isEmpty else { return false }

        switch event.keyCode {
        case KeyCode.downArrow:
            moveSelection(by: 1)
            return true
        case KeyCode.upArrow:
            moveSelection(by: -1)
            return true
        case KeyCode.returnKey, KeyCode.keypadEnter:
            copySelectedItem()
            return true
        case KeyCode.escape:
            handleEscape()
            return true
        default:
            return false
        }
    }

    private func moveSelection(by offset: Int) {
        let items = viewModel.items
        guard !items.isEmpty else {
            selectedItemID = nil
            return
        }

        if let current = selectedIndex {
            let next = min(max(current + offset, 0), items.count - 1)
            selectedItemID = items[next].id
        } else {
            selectedItemID = offset > 0 ? items.first?.id : items.last?.id
        }
    }

    private func copySelectedItem() {
        copyItem(at: selectedIndex ?? 0)
    }

    private func copyItem(at index: Int) {
        guard viewModel.items.indices.contains(index) else { return }
        let item = viewModel.items[index]
        selectedItemID = item.id
        viewModel.copyToClipboard(item)
    }

    private func handleEscape() {
        if viewModel.searchText.isEmpty {
            StatusBarController.shared?.closePopover()
        } else {
            viewModel.setSearchText("")
        }
    }
}

private enum KeyCode {
    static let returnKey: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let escape: UInt16 = 53
    static let upArrow: UInt16 = 126
    static let downArrow: UInt16 = 125
}
