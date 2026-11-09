import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSApplicationDelegate {
    nonisolated(unsafe) static weak var shared: StatusBarController?

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        StatusBarController.shared = self
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "clipboard",
                accessibilityDescription: "ClipHistory"
            )
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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
        menu.addItem(NSMenuItem(
            title: "Quit ClipHistory",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
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
