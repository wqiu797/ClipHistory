import AppKit
import SwiftUI

/// Installs a local key monitor for as long as the hosting view is inside a window. Used by the
/// popover to implement arrow-key navigation without stealing keys when the panel is closed.
struct KeyEventHandler: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.onKeyDown = onKeyDown
    }

    final class MonitorView: NSView {
        var onKeyDown: ((NSEvent) -> Bool)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            if window == nil {
                removeMonitor()
            } else {
                installMonitor()
            }
        }

        private func installMonitor() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                // `assumeIsolated` needs a Sendable result, so only the Bool crosses the boundary.
                let handled = MainActor.assumeIsolated { () -> Bool in
                    guard let self, self.window?.isKeyWindow == true else { return false }
                    return self.onKeyDown?(event) ?? false
                }
                return handled ? nil : event
            }
        }

        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }
    }
}
