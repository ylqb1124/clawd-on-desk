import SwiftUI

/// Settings view accessible from menu bar
struct SettingsView: View {
    @StateObject private var viewModel = PetViewModel.shared

    var body: some View {
        TabView {
            GeneralSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AppearanceSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 400, height: 280)
    }
}

// MARK: - General Settings
struct GeneralSettingsView: View {
    @ObservedObject var viewModel: PetViewModel
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showStatusLabel") private var showStatusLabel = true
    @AppStorage("enableEyeTracking") private var enableEyeTracking = true
    @AppStorage("monitorInterval") private var monitorInterval = 2.0

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Show status label", isOn: $showStatusLabel)
                Toggle("Eye tracking (follow cursor)", isOn: $enableEyeTracking)
            }

            Section("Monitoring") {
                HStack {
                    Text("Poll interval")
                    Slider(value: $monitorInterval, in: 1...10, step: 0.5)
                    Text("\(monitorInterval, specifier: "%.1f")s")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 35)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Appearance Settings
struct AppearanceSettingsView: View {
    @ObservedObject var viewModel: PetViewModel

    var body: some View {
        Form {
            Section("Preview") {
                HStack {
                    Spacer()
                    PetSpriteView(
                        state: .idle,
                        frame: 0
                    )
                    .frame(width: 80, height: 80)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About
struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkle")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("ClawdOnDesk")
                .font(.system(size: 16, weight: .semibold))

            Text("v1.0.0")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text("A macOS desktop pet that reacts to your\nClaude Code sessions in real-time.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            Text("Built with Swift + SwiftUI")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
