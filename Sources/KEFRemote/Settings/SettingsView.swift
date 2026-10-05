import KEFRemoteCore
import KeyboardShortcuts
import SwiftUI

/// The settings window: only fields that change something now.
///
/// ```
/// Speaker      IP [192.168.1.80] (Save) (Discover)
///              Found LSX at 192.168.1.80
/// Media keys   Modifier [Control]
/// Shortcuts    Power on/off, Volume up, Volume down, Mute, Quit
/// ```
struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("Speaker") {
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

                HStack {
                    Button("Discover") {
                        Task { await model.discover() }
                    }
                    .disabled(model.isDiscovering)

                    if model.isDiscovering {
                        ProgressView().controlSize(.small)
                    }

                    if let note = model.note {
                        Text(note)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Discover finds the speaker on this network and saves its IP.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

                Text("Hold this key with a volume or mute key to control the speaker instead of the Mac.")
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
                }

                Text("Click a field, then press the new keys. Delete clears it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}
