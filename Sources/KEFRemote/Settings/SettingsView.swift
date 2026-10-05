import KEFRemoteCore
import KeyboardShortcuts
import SwiftUI

/// The settings window: only fields that change something now.
///
/// ```
/// Speaker      Discovery (Auto | Manual)
///   Auto:      Speaker LSX · IP 192.168.1.80 · Status Connected (Find again)
///   Manual:    IP [192.168.1.80] (Save)
/// Media keys   Modifier [Control]   "Control + the volume keys … changes the speaker"
/// Shortcuts    Power on/off, Volume up, Volume down, Mute, Quit
///              "Optional extra keys. They work alongside the volume keys above."
/// ```
struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    /// The live speaker and connection, as the menu bar shows them.
    @ObservedObject var menuBar: MenuBarModel

    var body: some View {
        Form {
            Section("Speaker") {
                Picker("Discovery", selection: Binding(
                    get: { model.discovery },
                    set: { model.setDiscovery($0) }
                )) {
                    Text("Auto").tag(DiscoveryMode.auto)
                    Text("Manual").tag(DiscoveryMode.manual)
                }
                .pickerStyle(.segmented)

                switch model.discovery {
                case .auto: autoDiscovery
                case .manual: manualIP
                }
            }

            Section("Media keys") {
                Picker("Modifier", selection: Binding(
                    get: { model.modifier },
                    set: { model.setModifier($0) }
                )) {
                    ForEach(MediaKeyModifier.allCases, id: \.self) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                .pickerStyle(.menu)

                // One line per way in: the modifier works with the keyboard's own keys.
                Text("\(model.modifier.displayName) + the volume keys 🔉 🔊 🔇 changes the speaker, not the Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Shortcuts") {
                ForEach(ShortcutAction.allCases, id: \.self) { action in
                    KeyboardShortcuts.Recorder(
                        "\(action.label):",
                        name: action.name,
                        onChange: { model.shortcutRecorded(action, as: $0) }
                    )
                    .shortcutValidation { model.validateShortcut($0, for: action) }
                }

                // The other way in: extra keys, which work alongside the modifier.
                Text("Optional extra keys. They work alongside the volume keys above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Click a field, then press the new keys. Delete clears it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Auto: the speaker the app found, read-only, and a way to look again.
    @ViewBuilder private var autoDiscovery: some View {
        LabeledContent("Speaker", value: menuBar.speakerName ?? "Not found yet")
        LabeledContent("IP address") {
            Text(menuBar.speakerIP ?? "None yet").textSelection(.enabled)
        }
        LabeledContent("Status", value: menuBar.presentation.isConnected ? "Connected" : menuBar.presentation.detail)

        HStack {
            Button("Find again") {
                Task { await model.discover() }
            }
            .disabled(model.isDiscovering)
            discoveryNote
        }

        Text("KEF Remote finds the speaker on this network, and finds it again if its IP changes.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// Manual: the IP the user types. The app never looks for another.
    @ViewBuilder private var manualIP: some View {
        LabeledContent("IP address") {
            HStack {
                TextField("IP address", text: $model.ipText, prompt: Text("192.168.1.80"))
                    .labelsHidden()
                    .frame(width: 150)
                    .onSubmit { model.saveIP() }
                Button("Save") { model.saveIP() }
                    .disabled(!model.canSaveIP)
            }
        }

        if let note = model.note {
            Text(note).foregroundStyle(.secondary)
        }

        Text("KEF Remote uses this IP and never looks for the speaker by itself.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// A spinner while looking, then the last result.
    @ViewBuilder private var discoveryNote: some View {
        if model.isDiscovering {
            ProgressView().controlSize(.small)
        }
        if let note = model.note {
            Text(note).foregroundStyle(.secondary)
        }
    }
}
