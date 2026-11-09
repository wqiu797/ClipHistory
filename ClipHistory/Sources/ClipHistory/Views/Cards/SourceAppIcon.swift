import AppKit
import SwiftUI

/// Small icon of the app that was frontmost when the item was copied.
struct SourceAppIcon: View {
    let bundleIdentifier: String?

    var body: some View {
        if let info = AppInfoCache.shared.info(for: bundleIdentifier) {
            Image(nsImage: info.icon)
                .resizable()
                .frame(width: 12, height: 12)
                .help(info.name)
                .accessibilityLabel(info.name)
        }
    }
}

@MainActor
final class AppInfoCache {
    static let shared = AppInfoCache()

    struct Info {
        let name: String
        let icon: NSImage
    }

    private var cache: [String: Info] = [:]
    private var missing: Set<String> = []

    func info(for bundleIdentifier: String?) -> Info? {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return nil }
        if let cached = cache[bundleIdentifier] { return cached }
        if missing.contains(bundleIdentifier) { return nil }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            missing.insert(bundleIdentifier)
            return nil
        }

        var name = FileManager.default.displayName(atPath: url.path)
        if name.hasSuffix(".app") {
            name.removeLast(4)
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 16, height: 16)

        let info = Info(name: name, icon: icon)
        cache[bundleIdentifier] = info
        return info
    }
}
