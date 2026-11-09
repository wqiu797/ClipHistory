import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSApplicationDelegate {
    nonisolated(unsafe) static weak var shared: StatusBarController?

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var defaultsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // When XCTest launches the app as its test host, leave the menu bar item,
        // clipboard monitor and database alone.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        StatusBarController.shared = self
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateStatusItemAppearance()

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItemAppearance()
            }
        }

        let contentView = PopoverRootView()
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)

        ClipboardMonitor.shared.start()
        CleanupScheduler.shared.start()
        sweepOrphanedImages()
    }

    // MARK: - Menu bar

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let pauseTitle = Preferences.isCapturePaused ? "Resume Recording" : "Pause Recording"
        let pauseItem = NSMenuItem(
            title: pauseTitle,
            action: #selector(togglePause),
            keyEquivalent: ""
        )
        pauseItem.target = self
        menu.addItem(pauseItem)

        let clearItem = NSMenuItem(
            title: "Clear All History…",
            action: #selector(clearAllHistory),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit ClipHistory",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func togglePause() {
        Preferences.isCapturePaused.toggle()
        updateStatusItemAppearance()
    }

    @objc private func clearAllHistory() {
        closePopover()

        let alert = NSAlert()
        alert.messageText = "Clear all clipboard history?"
        alert.informativeText =
            "This deletes every item, including pinned items and stored images. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        HistoryMaintenance.shared.clearAll()
    }

    private func updateStatusItemAppearance() {
        let paused = Preferences.isCapturePaused
        statusItem.button?.image = NSImage(
            systemSymbolName: paused ? "pause.circle" : "clipboard",
            accessibilityDescription: paused ? "ClipHistory paused" : "ClipHistory"
        )
        statusItem.button?.toolTip = paused ? "ClipHistory — recording paused" : "ClipHistory"
    }

    // MARK: - Popover

    private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        if popover.isShown {
            closePopover()
            return
        }
        guard let button = statusItem.button else { return }

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        focusSearchField()
    }

    func closePopover() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    /// Focuses the search field once the popover window is on screen so typing filters immediately.
    private func focusSearchField() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            self?.focusSearchFieldNow()
        }
    }

    private func focusSearchFieldNow() {
        guard let contentView = popover.contentViewController?.view,
              let window = contentView.window,
              let searchField = Self.firstSearchField(in: contentView)
        else { return }

        window.makeFirstResponder(searchField)
    }

    private static func firstSearchField(in view: NSView) -> NSSearchField? {
        if let searchField = view as? NSSearchField {
            return searchField
        }
        for subview in view.subviews {
            if let found = firstSearchField(in: subview) {
                return found
            }
        }
        return nil
    }

    // MARK: - Storage maintenance

    /// Removes image files that no longer belong to a database row (e.g. left behind by a crash).
    private func sweepOrphanedImages() {
        DispatchQueue.global(qos: .utility).async {
            do {
                let dao = ClipboardItemDAO()
                let activeFiles = try dao.allImageFileNames()
                ImageStore.shared.cleanupOrphanedFiles(activeFiles: Set(activeFiles))
            } catch {
                Log.images.error(
                    "Could not sweep orphaned images: \(String(describing: error), privacy: .public)"
                )
            }
        }
    }
}
