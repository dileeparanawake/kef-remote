import KEFRemoteCore
import SwiftUI

/// The setup window: three steps the first time, or step 1 on its own.
///
/// ```
/// 1 Permissions  ›  2 Find your speaker  ›  3 You're set
///
/// [step 1: PermissionsView]                Skip for now  [Continue]
///                                          or [Restart and continue]
/// [step 2: Auto | Manual, Find speaker]    Back          [Continue]
/// [step 3: what works now, Privacy link]                [Done]
/// ```
///
/// What unlocks Continue and what each line says are decided in
/// ``OnboardingStep`` and ``SpeakerSearchLine``; this only shows them.
/// The model passes on every change to the permissions, settings and
/// menu bar models, so each step redraws as the speaker answers.
struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel

    private let log = AppLogger(subsystem: "com.kef-remote", category: "onboarding")

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch model.mode {
            case .permissionsOnly:
                permissionsStep
            case .allSteps:
                stepIndicator
                switch model.step {
                case .permissions: permissionsStep
                case .findSpeaker: FindSpeakerStep(model: model, settings: model.settings)
                case .done: youreSet
                }
                buttons
            }
        }
        .padding(20)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var permissionsStep: some View {
        PermissionsView(model: model.permissions, restart: model.restartClicked, restartLine: model.permissionsRestartLine)
    }

    /// Where he is: the current step bold, the others grey.
    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                if step != .permissions {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                Text("\(step.number) \(step.title)")
                    .fontWeight(step == model.step ? .bold : .regular)
                    .foregroundStyle(step == model.step ? .primary : .secondary)
            }
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(model.step.number) of \(OnboardingStep.allCases.count): \(model.step.title)")
    }

    private var youreSet: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KEF Remote is ready")
                .font(.headline)
            ForEach(model.youreSetLines, id: \.self) { line in
                Text(line)
            }
            PrivacyLink(title: PrivacyNotice.setupTitle, log: log)
        }
    }

    /// Skip or Back on the left, quiet; Continue or Done on the right.
    private var buttons: some View {
        HStack {
            switch model.step {
            case .permissions:
                Button("Skip for now", action: model.skipClicked)
                    .buttonStyle(.link)
            case .findSpeaker:
                Button("Back", action: model.backClicked)
            case .done:
                EmptyView()
            }
            Spacer()
            if model.step == .done {
                Button("Done", action: model.doneClicked)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button(model.continueTitle, action: model.continueClicked)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canContinue)
            }
        }
    }
}

/// Step 2: Auto (recommended) finds the speaker, as Settings does;
/// Manual takes its IP.
///
/// ```
/// Find your speaker
/// [Auto (recommended) | Manual]
/// Auto:    [Find speaker] ◌ Looking for the speaker…
///          Not found: check it's on and on this network  [Enter the IP instead]
/// Manual:  IP address [192.168.1.80] [Save]
///          ✓ Found LSX at 192.168.1.80
/// ```
private struct FindSpeakerStep: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject var settings: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find your speaker")
                .font(.headline)

            Picker("Discovery", selection: Binding(
                get: { settings.discovery },
                set: { model.setDiscovery($0) }
            )) {
                Text("Auto (recommended)").tag(DiscoveryMode.auto)
                Text("Manual").tag(DiscoveryMode.manual)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch settings.discovery {
            case .auto:
                Button("Find speaker") {
                    Task { await model.findSpeaker() }
                }
                .disabled(model.searchLine.isBusy)
            case .manual:
                HStack {
                    Text("IP address")
                    TextField("IP address", text: $settings.ipText, prompt: Text("192.168.1.80"))
                        .labelsHidden()
                        .frame(width: 150)
                        .onSubmit { model.saveIP() }
                    Button("Save", action: model.saveIP)
                        .disabled(!settings.canSaveIP)
                }
            }

            searchLine

            Text(settings.discovery == .auto
                 ? "KEF Remote finds the speaker on this network, and finds it again if its IP changes."
                 : "KEF Remote uses this IP and never looks for the speaker by itself.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// A spinner while looking or connecting, then connected (a tick) or
    /// what to check.
    private var searchLine: some View {
        let line = model.searchLine
        return HStack(spacing: 6) {
            if line.isBusy {
                ProgressView().controlSize(.small)
            } else if case .connected = line {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
            }
            Text(line.text)
            if line.offersManual && settings.discovery == .auto {
                Button("Enter the IP instead", action: model.enterIPClicked)
                    .buttonStyle(.link)
            }
        }
    }
}
