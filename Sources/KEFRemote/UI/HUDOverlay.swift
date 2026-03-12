import AppKit
import os
import SwiftUI

// MARK: - HUD State

/// Represents the different states the HUD overlay can display.
///
/// Each state maps to a distinct visual presentation with an appropriate
/// SF Symbol icon and optional supplementary information (volume level,
/// error message).
enum HUDState {
    case volume(level: Int)
    case muted
    case powerOn
    case powerOff
    case waking
    case error(String)
}

// MARK: - Non-activating Panel

/// An NSPanel subclass that refuses to become key or main.
///
/// This prevents the HUD from stealing focus from whatever app the
/// user is currently working in. `NSPanel.canBecomeKey` is read-only,
/// so we must subclass to override it.
private final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - HUD Overlay

/// A floating, translucent overlay that provides visual feedback for
/// speaker state changes (volume, mute, power, errors).
///
/// The overlay mimics the macOS native volume/brightness OSD: a
/// rounded-rectangle panel with vibrancy blur that appears briefly
/// and fades out after 1.5 seconds.
///
/// Usage:
/// ```swift
/// HUDOverlay.show(.volume(level: 42))
/// HUDOverlay.show(.muted)
/// HUDOverlay.show(.powerOff)
/// ```
///
/// Calling `show(_:)` while the HUD is already visible resets the
/// auto-dismiss timer and updates the displayed content.
final class HUDOverlay {

    // MARK: - Constants

    private static let panelWidth: CGFloat = 220
    private static let panelHeight: CGFloat = 220
    private static let dismissDelay: TimeInterval = 1.5
    private static let animationDuration: TimeInterval = 0.2

    // MARK: - Singleton state

    private static let logger = Logger(subsystem: "com.kef-remote", category: "hud")
    private static var panel: NSPanel?
    private static var dismissTimer: Timer?
    private static var hostingView: NSHostingView<HUDContentView>?

    // MARK: - Public API

    /// Show the HUD with the given state.
    ///
    /// If the HUD is already visible, the content is updated in place
    /// and the auto-dismiss timer is reset. If the HUD is not visible,
    /// it fades in over 0.2 seconds.
    ///
    /// - Parameter state: The speaker state to display.
    static func show(_ state: HUDState) {
        // Must run on the main thread since we manipulate AppKit views.
        if !Thread.isMainThread {
            DispatchQueue.main.async { show(state) }
            return
        }

        logger.info("HUD show: \(String(describing: state), privacy: .public)")
        let panel = getOrCreatePanel()
        updateContent(state)
        positionOnScreen(panel)

        // Cancel any pending dismiss.
        dismissTimer?.invalidate()

        if !panel.isVisible {
            // Fade in from transparent.
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animationDuration
                panel.animator().alphaValue = 1
            }
        }

        // Schedule auto-dismiss.
        dismissTimer = Timer.scheduledTimer(
            withTimeInterval: dismissDelay,
            repeats: false
        ) { _ in
            dismiss()
        }
    }

    /// Dismiss the HUD immediately with a fade-out animation.
    static func dismiss() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { dismiss() }
            return
        }

        guard let panel = panel, panel.isVisible else { return }

        logger.debug("HUD dismiss")
        dismissTimer?.invalidate()
        dismissTimer = nil

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = animationDuration
            panel.animator().alphaValue = 0
        }, completionHandler: {
            // Only order out if no new show was triggered during the fade.
            if panel.alphaValue == 0 {
                panel.orderOut(nil)
            }
        })
    }

    // MARK: - Panel lifecycle

    private static func getOrCreatePanel() -> NSPanel {
        if let existing = panel {
            return existing
        }

        let newPanel = NonActivatingPanel(
            contentRect: NSRect(
                x: 0, y: 0,
                width: panelWidth, height: panelHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.level = .floating
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.hidesOnDeactivate = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hosting = NSHostingView(rootView: HUDContentView(state: .volume(level: 0)))
        hosting.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        newPanel.contentView = hosting

        panel = newPanel
        hostingView = hosting

        return newPanel
    }

    private static func updateContent(_ state: HUDState) {
        hostingView?.rootView = HUDContentView(state: state)
    }

    private static func positionOnScreen(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        // Center horizontally, place in the lower third vertically.
        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.minY + screenFrame.height / 3 - panelHeight / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - Visual Effect View (NSVisualEffectView wrapper)

/// A SwiftUI wrapper around `NSVisualEffectView` that provides the
/// frosted-glass vibrancy effect used by the HUD background.
private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        // Allow the view to be transparent so the panel's clear
        // background shows through outside the rounded rectangle.
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - HUD Content View

/// The SwiftUI view displayed inside the HUD panel.
///
/// Layout (top to bottom):
/// 1. SF Symbol icon representing the current state
/// 2. Status label (e.g. "42%", "Muted", "Power Off")
/// 3. Volume bar (only for `.volume` state)
private struct HUDContentView: View {
    let state: HUDState

    var body: some View {
        ZStack {
            // Frosted-glass background.
            VisualEffectView(
                material: .hudWindow,
                blendingMode: .behindWindow
            )

            VStack(spacing: 12) {
                Spacer()

                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(.primary)

                // Label
                Text(label)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)

                // Volume bar (only for volume state)
                if case .volume(let level) = state {
                    volumeBar(level: level)
                        .padding(.horizontal, 24)
                }

                Spacer()
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .frame(width: 220, height: 220)
    }

    // MARK: - State-derived properties

    private var iconName: String {
        switch state {
        case .volume(let level):
            if level == 0 {
                return "speaker.fill"
            } else if level < 33 {
                return "speaker.wave.1.fill"
            } else if level < 66 {
                return "speaker.wave.2.fill"
            } else {
                return "speaker.wave.3.fill"
            }
        case .muted:
            return "speaker.slash.fill"
        case .powerOn:
            return "power"
        case .powerOff:
            return "power"
        case .waking:
            return "antenna.radiowaves.left.and.right"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var label: String {
        switch state {
        case .volume(let level):
            return "\(level)%"
        case .muted:
            return "Muted"
        case .powerOn:
            return "Power On"
        case .powerOff:
            return "Power Off"
        case .waking:
            return "Waking..."
        case .error(let message):
            return message
        }
    }

    // MARK: - Volume bar

    private func volumeBar(level: Int) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.quaternary)
                    .frame(height: 8)

                // Fill
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.primary)
                    .frame(
                        width: geometry.size.width * CGFloat(min(max(level, 0), 100)) / 100,
                        height: 8
                    )
            }
        }
        .frame(height: 8)
    }
}
