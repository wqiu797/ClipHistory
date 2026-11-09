import SwiftUI

struct GeneralSettingsTab: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Picker("Keep clipboard history for:", selection: $viewModel.retentionDays) {
                    Text("1 day").tag(1)
                    Text("3 days").tag(3)
                    Text("5 days").tag(5)
                }
                .pickerStyle(.radioGroup)
            }

            Section {
                Toggle("Launch at login", isOn: $viewModel.launchAtLogin)

                if let message = viewModel.loginItemError {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                    Button("Open Login Items Settings…") {
                        viewModel.openLoginItemsSettings()
                    }
                    .font(.caption)
                }
            }

            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(versionText)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var versionText: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String
        if let build, !build.isEmpty {
            return "\(version) (\(build))"
        }
        return version
    }
}
