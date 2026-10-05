import Foundation
import KEFRemoteCore

// Runs speaker discovery once and prints every step.
//
//   make discover                      # take the first KEF
//   make discover MAC=a1:b2:c3:d4:e5:f6  # only the KEF with this MAC
//
// Run from Terminal, macOS's Local Network prompt does not apply, so a
// pass here does not prove the app itself is allowed on the network.

let arguments = CommandLine.arguments
let savedMAC = arguments.firstIndex(of: "--mac").flatMap { index in
    index + 1 < arguments.count ? arguments[index + 1] : nil
}

let log = HandlerLog { level, message in
    let label: String
    switch level {
    case .debug: label = "DEBUG"
    case .info: label = "INFO "
    case .warning: label = "WARN "
    case .error: label = "ERROR"
    }
    print("[\(label)] \(message)")
}

do {
    if let speaker = try await SpeakerFinder.onNetwork(log: log).find(savedMAC: savedMAC) {
        print("Found \(speaker.name) at \(speaker.ip), MAC \(speaker.mac)")
    } else {
        print("No KEF speaker found")
        exit(1)
    }
} catch {
    print("Discovery failed: \(error)")
    exit(2)
}
