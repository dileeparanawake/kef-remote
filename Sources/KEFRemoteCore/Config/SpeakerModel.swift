import Foundation

/// Which KEF speaker the saved one is, as far as the app can tell, for
/// the inputs it has.
///
/// KEF's spec: the LSX has Wi-Fi, Bluetooth, Optical and Aux; the LS50
/// Wireless also has USB. In the second real check (6 Oct 2026) the LSX,
/// asked for USB, stayed on Aux. So USB is left out of Input ▸, Input on
/// turn-on and the check's `--inputs` for an LSX.
public enum SpeakerModel: Equatable, Sendable {
    case lsx
    /// The LS50 Wireless, or a speaker the app can't tell: every input
    /// is offered, as before.
    case other

    /// The LSX's model name in its description.xml. Discovery logged
    /// "KEF LSX (SP3994)": its name, then its model.
    static let lsxModelName = "SP3994"

    /// Tells the model from what discovery saved. The model name decides
    /// when there is one. A config saved before the model was kept only
    /// has the name, which is "LSX" out of the box.
    public init(_ speaker: AppConfig.SpeakerConfig?) {
        let model = (speaker?.model ?? "").trimmingCharacters(in: .whitespaces)
        let isLSX: Bool
        if model.isEmpty {
            isLSX = (speaker?.name ?? "").localizedCaseInsensitiveContains("LSX")
        } else {
            isLSX = model.caseInsensitiveCompare(Self.lsxModelName) == .orderedSame
                || model.localizedCaseInsensitiveContains("LSX")
        }
        self = isLSX ? .lsx : .other
    }

    public var hasUSBInput: Bool { self != .lsx }

    /// The inputs to switch to, in Input on turn-on's order.
    public var inputs: [InputSource] {
        PowerOnInput.allCases.compactMap(\.input).filter { $0 != .usb || hasUSBInput }
    }

    /// The choices for Input on turn-on. USB stays while it is the saved
    /// choice, so the picker never shows a choice it doesn't list.
    public func powerOnChoices(keeping current: PowerOnInput) -> [PowerOnInput] {
        PowerOnInput.allCases.filter { $0 != .usb || hasUSBInput || current == .usb }
    }

    /// "LSX: no USB input", for logs and the check.
    public var label: String {
        switch self {
        case .lsx: return "LSX: no USB input"
        case .other: return "not an LSX: every input"
        }
    }
}
