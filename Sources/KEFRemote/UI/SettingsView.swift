import KEFRemoteCore
import KeyboardShortcuts
import SwiftUI

// MARK: - Settings View Model

/// Manages the settings state, loading and saving to AppConfig on disk.
///
/// Uses `ObservableObject` with `@Published` for SwiftUI change tracking
/// (compatible with macOS 13+). The view model loads config from
/// `~/.kef-remote/config.json` on init and saves back on every change
/// via the view's `onChange` modifier.
///
/// **Note:** This view model is not wired to the speaker — it only
/// reads/writes the persisted configuration. The integration task
/// (Task 22) will connect config changes to the live speaker controller.
final class SettingsViewModel: ObservableObject {
    @Published var config: AppConfig

    /// Placeholder connection status. Will be driven by the speaker
    /// controller in Task 22.
    @Published var connectionStatus: String = "Not connected"

    /// Placeholder for discovery in progress. Will be driven by
    /// SSDPDiscovery in Task 22.
    @Published var isDiscovering: Bool = false

    init() {
        let configURL = Self.configFileURL
        config = (try? AppConfig.load(from: configURL)) ?? AppConfig()
    }

    func save() {
        try? AppConfig.save(config, to: Self.configFileURL)
    }

    static var configFileURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kef-remote")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }
}

// MARK: - Settings View

/// The main settings window for KEF Remote.
///
/// Organised into tabs:
/// - **Speaker:** IP address, MAC, name, discovery, connection status
/// - **Audio:** Default input source and standby timeout
/// - **Hotkeys:** Keyboard shortcuts for power on/off and quit
/// - **Lifecycle:** Wake/sleep power management
/// - **Network:** Home SSID for location awareness
/// - **App:** Launch at login, quit
///
/// Changes are auto-saved to `~/.kef-remote/config.json` whenever any
/// config field is modified. The settings window opens when the app is
/// re-launched while already running (handled by AppDelegate).
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        TabView {
            speakerTab
                .tabItem {
                    Label("Speaker", systemImage: "hifispeaker")
                }

            audioTab
                .tabItem {
                    Label("Audio", systemImage: "tuningfork")
                }

            hotkeysTab
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }

            lifecycleTab
                .tabItem {
                    Label("Lifecycle", systemImage: "powersleep")
                }

            networkTab
                .tabItem {
                    Label("Network", systemImage: "wifi")
                }

            appTab
                .tabItem {
                    Label("App", systemImage: "gearshape")
                }
        }
        .frame(width: 450, height: 350)
        .onChange(of: viewModel.config) { _ in
            viewModel.save()
        }
    }

    // MARK: - Speaker Tab

    private var speakerTab: some View {
        Form {
            Section("Speaker Details") {
                TextField(
                    "IP Address",
                    text: Binding(
                        get: { viewModel.config.speaker?.lastKnownIp ?? "" },
                        set: { newValue in
                            ensureSpeakerConfig()
                            viewModel.config.speaker?.lastKnownIp = newValue.isEmpty ? nil : newValue
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)

                TextField(
                    "MAC Address",
                    text: Binding(
                        get: { viewModel.config.speaker?.mac ?? "" },
                        set: { newValue in
                            ensureSpeakerConfig()
                            viewModel.config.speaker?.mac = newValue.isEmpty ? nil : newValue
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)

                TextField(
                    "Speaker Name",
                    text: Binding(
                        get: { viewModel.config.speaker?.name ?? "" },
                        set: { newValue in
                            ensureSpeakerConfig()
                            viewModel.config.speaker?.name = newValue.isEmpty ? nil : newValue
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
            }

            Section("Discovery") {
                HStack {
                    Button("Discover") {
                        // Placeholder — will be wired to SSDPDiscovery in Task 22.
                        viewModel.isDiscovering = true
                    }
                    .disabled(viewModel.isDiscovering)

                    if viewModel.isDiscovering {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.leading, 4)
                    }
                }

                LabeledContent("Status") {
                    Text(viewModel.connectionStatus)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Audio Tab

    private var audioTab: some View {
        Form {
            Section("Default Input Source") {
                Picker("Input", selection: $viewModel.config.defaults.input) {
                    Text("Wi-Fi").tag(InputSource.wifi)
                    Text("USB").tag(InputSource.usb)
                    Text("Bluetooth").tag(InputSource.bluetoothPaired)
                    Text("Aux").tag(InputSource.aux)
                    Text("Optical").tag(InputSource.optical)
                }
                .pickerStyle(.menu)
            }

            Section("Standby Timeout") {
                Picker("Standby", selection: $viewModel.config.defaults.standby) {
                    Text("60 Minutes").tag(StandbyMode.sixtyMinutes)
                    Text("Never").tag(StandbyMode.never)
                }
                .pickerStyle(.menu)

                Text("20-minute standby is not available — it causes the speaker to crash on power-off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Hotkeys Tab

    private var hotkeysTab: some View {
        Form {
            Section("Media Key Modifier") {
                Picker("Modifier", selection: modifierBinding) {
                    Text("Shift").tag(ModifierChoice.shift)
                    Text("Control").tag(ModifierChoice.control)
                    Text("Option").tag(ModifierChoice.option)
                    Text("Command").tag(ModifierChoice.command)
                }
                .pickerStyle(.menu)

                Text("Hold this modifier and press media keys to control the KEF speaker instead of the Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Power Shortcuts") {
                KeyboardShortcuts.Recorder("Power On:", name: .powerOn)
                KeyboardShortcuts.Recorder("Power Off:", name: .powerOff)
                KeyboardShortcuts.Recorder("Quit:", name: .quit)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Lifecycle Tab

    private var lifecycleTab: some View {
        Form {
            Section("Wake / Sleep") {
                Toggle("Power on speaker when Mac wakes", isOn: $viewModel.config.lifecycle.powerOnWake)
                Toggle("Power off speaker when Mac sleeps", isOn: $viewModel.config.lifecycle.powerOffSleep)
            }

            Section("Power-Off Delay") {
                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.config.lifecycle.powerOffDelay) },
                            set: { viewModel.config.lifecycle.powerOffDelay = Int($0) }
                        ),
                        in: 10...300,
                        step: 10
                    )

                    Text("\(viewModel.config.lifecycle.powerOffDelay)s")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }

                Text("Delay before powering off after sleep. Prevents power cycling during brief sleep events (e.g. lid close with external display).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Network Tab

    private var networkTab: some View {
        Form {
            Section("Home Network") {
                TextField(
                    "Home SSID",
                    text: Binding(
                        get: { viewModel.config.network.homeSSID ?? "" },
                        set: { newValue in
                            viewModel.config.network.homeSSID = newValue.isEmpty ? nil : newValue
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)

                Text("When set, the app only controls the speaker while connected to this Wi-Fi network.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Reset Home Network") {
                    viewModel.config.network.homeSSID = nil
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - App Tab

    private var appTab: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $viewModel.config.app.launchAtLogin)
            }

            Section {
                Button("Quit KEF Remote") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Helpers

    /// Ensure the speaker config struct exists before setting fields on it.
    private func ensureSpeakerConfig() {
        if viewModel.config.speaker == nil {
            viewModel.config.speaker = AppConfig.SpeakerConfig()
        }
    }

    // MARK: - Modifier choice (for media key interception)

    /// Represents the modifier key choices for media key interception.
    ///
    /// This is a UI-only enum for the settings picker. The actual
    /// CGEventFlags mapping happens in MediaKeyInterceptor, which reads
    /// from a stored preference. For now, the modifier choice is stored
    /// locally via `@AppStorage` — it will be wired to the interceptor
    /// in Task 22.
    private enum ModifierChoice: String, CaseIterable {
        case shift = "shift"
        case control = "control"
        case option = "option"
        case command = "command"
    }

    /// Binding that stores the media key modifier preference.
    ///
    /// Uses `@AppStorage` style persistence via UserDefaults. The
    /// actual mapping to `CGEventFlags` is handled by the integration
    /// layer in Task 22.
    private var modifierBinding: Binding<ModifierChoice> {
        Binding(
            get: {
                let stored = UserDefaults.standard.string(forKey: "mediaKeyModifier") ?? "shift"
                return ModifierChoice(rawValue: stored) ?? .shift
            },
            set: { newValue in
                UserDefaults.standard.set(newValue.rawValue, forKey: "mediaKeyModifier")
            }
        )
    }
}
