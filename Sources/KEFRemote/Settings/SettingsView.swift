import KEFRemoteCore
import KeyboardShortcuts
import SwiftUI

/// The settings window, in three tabs so it fits a 13-inch MacBook
/// (``SettingsTab``). Only fields that change something now.
///
/// ```
/// [ Speaker ]  [ Keys ]  [ About ]
///
/// Speaker   Connection   Discovery (Auto | Manual)
///             Auto:      Speaker LSX · IP 192.168.1.80 · Status Connected (Find again)
///             Manual:    IP [192.168.1.80] (Save)
///           Speaker      Input on turn-on [Don't change]
///                          "When KEF Remote turns the speaker on."
///                        Standby [Don't change]
///                          "Now, and each time KEF Remote connects."
///                        Swap left and right [off]
///                          "Now. The speaker remembers it."
/// Keys      Media keys   Modifier [Control]   "Control + the volume keys …"
///           Shortcuts    Power on/off, Volume up, … Quit
///                        "Optional extra keys. They work alongside the keys above."
/// About     KEF Remote   Version 0.3.0 (3)
///                        Made by Dileepa ↗
///                        Send feedback…
///                        Privacy: KEF Remote collects nothing
/// ```
///
/// A tab taller than ``SettingsTab/maxContentHeight`` scrolls. Each tab
/// change logs one line under `settings`: `tab Speaker -> Keys`.
struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    /// The live speaker and connection, as the menu bar shows them.
    @ObservedObject var menuBar: MenuBarModel
    /// Send feedback… in the About tab, as in the menu.
    let sendFeedback: () -> Void

    @State private var tab: SettingsTab = .first

    private let log = AppLogger(subsystem: "com.kef-remote", category: "settings")

    var body: some View {
        TabView(selection: $tab) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                content(of: tab)
                    .formStyle(.grouped)
                    // A grouped Form scrolls, so a tall tab stays on screen.
                    .frame(maxHeight: SettingsTab.maxContentHeight)
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
            }
        }
        .onChange(of: tab) { old, new in log.info("tab \(old.title) -> \(new.title)") }
        .padding(.top, 8)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func content(of tab: SettingsTab) -> some View {
        switch tab {
        case .speaker: speakerTab
        case .keys: keysTab
        case .about: aboutTab
        }
    }

    private var speakerTab: some View {
        Form {
            // "Connection", so it doesn't share the Speaker section's name.
            Section("Connection") {
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

            // Its own section, apart from how the app finds the speaker.
            // Each row applies at a different time, so each says when
            // under its title (a second Text in a grouped Form's label).
            Section("Speaker") {
                Picker(selection: Binding(
                    get: { model.powerOnInput },
                    set: { model.setPowerOnInput($0) }
                )) {
                    ForEach(model.powerOnInputChoices, id: \.self) { choice in
                        Text(choice.label).tag(choice)
                    }
                } label: {
                    Text("Input on turn-on")
                    Text(PowerOnInput.settingsCaption)
                }
                .pickerStyle(.menu)

                Picker(selection: Binding(
                    get: { model.standby },
                    set: { model.setStandby($0) }
                )) {
                    ForEach(StandbyChoice.allCases, id: \.self) { choice in
                        Text(choice.label).tag(choice)
                    }
                } label: {
                    Text("Standby")
                    Text(StandbyChoice.settingsCaption)
                }
                .pickerStyle(.menu)

                swapLeftRight
            }
        }
    }

    private var keysTab: some View {
        Form {
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
                Text("\(model.modifier.displayName) + the volume keys 🔉 🔊 🔇 change the speaker, not the Mac.")
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
                Text("Optional extra keys. They work alongside the keys above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Click a field, then press the new keys. Delete clears it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The version, and the same links as the menu.
    private var aboutTab: some View {
        Form {
            Section {
                LabeledContent("KEF Remote") {
                    Text(AppVersion.current.aboutLine).textSelection(.enabled)
                }
            }

            Section {
                ForEach(MenuLink.shown, id: \.self) { link in
                    Button(link.title) { link.open(from: "About", log: log) }
                        .buttonStyle(.link)
                }

                if FeedbackEmail.isShown {
                    Button(FeedbackEmail.menuTitle) {
                        log.info("About: \(FeedbackEmail.menuTitle) clicked")
                        sendFeedback()
                    }
                    .buttonStyle(.link)
                }

                PrivacyLink(title: PrivacyNotice.settingsTitle, log: log)
            }
        }
    }

    /// The speaker's own swap, as last read, applied when clicked.
    @ViewBuilder private var swapLeftRight: some View {
        let shown = SwapLeftRightSwitch(
            speakerSource: menuBar.speakerSource,
            isConnected: menuBar.presentation.isConnected,
            requested: model.requestedSwap
        )
        Toggle(isOn: Binding(
            get: { shown.isOn },
            set: { isSwapped in Task { await model.setLeftRightSwapped(isSwapped) } }
        )) {
            Text(SwapLeftRightSwitch.title)
            Text(SwapLeftRightSwitch.settingsCaption)
        }
        .toggleStyle(.switch)
        .disabled(!shown.isEnabled)

        if let note = model.swapNote {
            Text(note).foregroundStyle(.secondary)
        }
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
