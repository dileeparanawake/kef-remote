import Foundation
import KEFRemoteCore

// Runs every speaker command, reads each one back, then puts the
// starting state back. Prints PASS / FAIL per step; exits 1 on a failure.
//
//   make speaker-check             # volume, mute, power, standby, left/right
//   make speaker-check INPUTS=1    # also each input in turn
//   make speaker-check DRY_RUN=1   # a simulated speaker: nothing is sent
//   make speaker-check PLAYBACK=1  # also play/pause twice on Wi-Fi and Bluetooth
//                                  # (it starts music, so it's off by default)
//
// It changes what the speaker plays: run it only when nobody is listening.
// Quit KEF Remote first: the speaker takes one connection at a time.
// Real runs log under [check] in ~/.kef-remote/logs/kef-remote.log.

let usage = "Usage: kef-check [--inputs] [--playback] [--dry-run]"
let arguments = Set(CommandLine.arguments.dropFirst())
let unknown = arguments.subtracting(["--inputs", "--playback", "--dry-run"])
guard unknown.isEmpty else {
    print("Unknown option: \(unknown.sorted().joined(separator: " "))\n\(usage)")
    exit(2)
}
let includingInputs = arguments.contains("--inputs")
let includingPlayback = arguments.contains("--playback")
let isDryRun = arguments.contains("--dry-run")

let connection: SpeakerConnection
let log: KEFLog
let clock: SpeakerClock
let model: SpeakerModel

if isDryRun {
    print("Dry run: a simulated speaker on simulated time, nothing is sent and nothing is logged")
    // Like the real runs: an LSX (no USB input) that starts off, is slow
    // to power on and off, and reads muted for a moment as it comes on.
    let simulatedClock = SimulatedClock()
    connection = SimulatedSpeaker(
        volume: VolumeState(level: 30, isMuted: false),
        source: SourceByte(isPoweredOn: false, isInversed: false, standby: .sixtyMinutes, input: .optical),
        hasUSBInput: false,
        clock: simulatedClock,
        powerChangeTime: .seconds(7),
        ignoresPowerChangesFor: .seconds(12),
        mutedAsItComesOnFor: .milliseconds(500)
    )
    log = HandlerLog { _, _ in }
    clock = simulatedClock
    model = .lsx
} else {
    let config: AppConfig
    do {
        config = try AppConfig.load(from: AppConfig.defaultFileURL)
    } catch {
        print("Could not read \(AppConfig.defaultFileURL.path): \(error)")
        exit(2)
    }
    guard let ip = config.speaker?.lastKnownIp else {
        print("No speaker IP in \(AppConfig.defaultFileURL.path). Run the app or make discover first.")
        exit(2)
    }
    // Appends, so the app's last session stays in the file.
    let writer = LogFileWriter(fileURL: LogFileWriter.defaultFileURL, echo: { _ in }, appending: true)
    let fileLog = HandlerLog { level, message in writer.write(level, category: "check", message: message) }
    fileLog.info("kef-check: checking the speaker at \(ip)\(includingInputs ? ", with inputs" : "")")
    print("Checking the speaker at \(ip)\(includingInputs ? ", with inputs" : "")")
    model = SpeakerModel(config.speaker)
    connection = TCPSpeakerConnection(host: ip, log: fileLog.write)
    log = fileLog
    clock = RealSpeakerClock()
}

if includingInputs {
    print("Speaker: \(model.label)")
    log.info("kef-check: speaker \(model.label)")
}
let check = SpeakerCheck(connection: connection, log: log, clock: clock, onLine: { print($0) })
let report = await check.run(includingInputs: includingInputs, includingPlayback: includingPlayback, model: model)
exit(report.passed ? 0 : 1)
