import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let showClipHistory = Self("showClipHistory", default: .init(.v, modifiers: [.command, .shift]))
}

struct HotkeySettingsTab: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Show clipboard history:")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .showClipHistory)
                }
            }

            Section {
                Text("Press the shortcut to quickly open the clipboard history panel.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
