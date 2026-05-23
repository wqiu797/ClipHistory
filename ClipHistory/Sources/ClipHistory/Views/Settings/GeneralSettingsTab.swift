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
            }

            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
