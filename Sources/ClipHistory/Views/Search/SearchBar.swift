import AppKit
import SwiftUI

struct SearchBar: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.placeholderString = "Search clipboard history..."
        searchField.delegate = context.coordinator
        searchField.sendsWholeSearchString = false
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        // Keep the native field in sync when the query is changed programmatically (e.g. Esc).
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        let parent: SearchBar

        init(_ parent: SearchBar) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let searchField = obj.object as? NSSearchField else { return }
            parent.text = searchField.stringValue
        }
    }
}
