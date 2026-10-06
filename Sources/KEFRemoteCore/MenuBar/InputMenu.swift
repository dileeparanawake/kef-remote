import Foundation

/// The Input ▸ submenu: the inputs to switch the speaker to now, with a
/// tick on the one it's on.
///
/// ```
/// Connected to LSX
/// 192.168.1.80
/// ─────────────
/// Input  ▸  ✓ Optical
///             Wi-Fi
///             Bluetooth
///             Aux
///             USB      (not on an LSX)
/// ```
///
/// The inputs come in the same order as Input on turn-on in Settings,
/// only those the speaker has (``SpeakerModel/inputs``).
/// The tick comes from the speaker's last source byte, read on connect
/// and read back after each switch.
public struct InputMenu: Equatable, Sendable {
    /// One input in the submenu.
    public struct Item: Equatable, Sendable {
        /// What picking it writes. Bluetooth writes the paired code, as
        /// Input on turn-on does.
        public let input: InputSource
        /// The speaker is on this input.
        public let isTicked: Bool

        public var title: String { input.label }
    }

    public static let title = "Input"

    public let items: [Item]
    /// Greyed out while the speaker isn't connected, since a switch
    /// couldn't reach it. It stays in the menu rather than hiding, so the
    /// menu keeps its shape and Input is where he left it.
    ///
    /// Not greyed while the last read said off: KEF's own remote can turn
    /// the speaker on without the app seeing it, which would leave Input
    /// greyed. A switch reads the speaker first instead, and says "Speaker
    /// is off" if it is (``SpeakerController/switchInput(to:)``).
    public let isEnabled: Bool

    /// - Parameters:
    ///   - speakerSource: The last source byte read or written, or nil
    ///     before the first read.
    ///   - isConnected: The speaker answered the last exchange.
    ///   - inputs: The inputs the speaker has, in order.
    public init(speakerSource: SourceByte?, isConnected: Bool, inputs: [InputSource]) {
        isEnabled = isConnected
        // Once the speaker stops answering, its input may have changed
        // (KEF's remote, or its own app), so tick nothing. It reports
        // Bluetooth as unpaired while nothing is paired, but it's the
        // same Bluetooth item.
        let ticked = isConnected ? speakerSource?.input.codeToSelect : nil
        items = inputs.map { input in
            Item(input: input, isTicked: input == ticked)
        }
    }
}
