# KEF Remote

Native macOS app for controlling KEF wireless speakers (LS50 Wireless and LSX) over TCP. Runs as a background agent (LSUIElement=true) with no dock or menu bar icon, intercepting media keys and providing a HUD overlay for volume/source feedback.

## Codebase

Two targets in a Swift package:

- **KEFRemoteCore** (library) — Testable protocol, command, and controller logic. No UI, no system frameworks beyond Foundation.
- **KEFRemoteCore** folders: `Protocol/` (byte encoding), `Commands/` (`SpeakerController`), `Connection/` (TCP), `Config/` (`config.json`), `Discovery/` (SSDP), `Logging/`.
- **KEFRemote** (executable) — macOS app with HUD overlay, hotkey interception (`Control/`), logging to file (`Logging/`), and system integration. A settings view exists (`UI/SettingsView.swift`) but its window doesn't open yet.

**Tech stack:** Swift, macOS 14+, SPM + Xcode project, Network.framework (TCP), CoreWLAN, KeyboardShortcuts, CGEvent tap, Swift Testing.

## Building and running

- **Build and run:** `open KEFRemote.xcodeproj` then Cmd+B / Cmd+R
- **Do NOT use `xed .`** when the xcodeproj exists (opens SPM package instead)
- **Edit code:** Cursor + Claude CLI (not Xcode)
- **Run tests:** `swift test --disable-sandbox`
- **Signing:** Automatic, personal development team, sandbox disabled

## Makefile

Use `make <target>` for common operations. Key targets:

| Target | Purpose |
|--------|---------|
| `make test` | Run test suite (`swift test --disable-sandbox`) |
| `make discover` | Find the speaker over SSDP and print every step (`MAC=...` to match one) |
| `make run` | Launch most recently built debug app |
| `make package` | Zip the latest Release build into `dist/KEFRemote-<version>.zip` (`ditto --norsrc --keepParent`) |
| `make kill` | Stop all running KEFRemote instances |
| `make logs-recent` | Last 200 lines from log file (quick agent snapshot) |
| `make logs-tail` | Live stream from log file |
| `make logs` | Unified logging stream (standalone only) |
| `make logs-debug` | Full trace including bytes on the wire (standalone only) |
| `make logs-errors` | Errors only (standalone only) |
| `make kef-on/off/status` | Hardware control via kefctl (for manual testing) |
| `make kef-raw-volume VOL=70` | Set volume directly via kefctl |

## Project structure

- `Package.swift` — Swift package manifest (two targets)
- `KEFRemote.xcodeproj/` — Xcode project for bundling, signing, running
- `Sources/KEFRemoteCore/` — Core library (protocol, commands, controller)
- `Sources/KEFRemote/` — macOS app (UI, hotkeys, lifecycle, integration)
- `Sources/KEFRemote/Info.plist` — App metadata (bundle ID, LSUIElement)
- `Sources/KEFRemote/KEFRemote.entitlements` — Permission declarations
- `Tests/KEFRemoteCoreTests/` — Unit tests for core library
- `~/.kef-remote/config.json` — User config (speaker IP, MAC, preferences)

## KEF speaker protocol

- **Connection:** TCP on port 50001
- **Commands:** GET sends 3 bytes, receives 5 bytes; SET sends 4 bytes, receives 3 bytes (ack)
- **Registers:** 0x25 (volume), 0x30 (source/power/standby)
- **Volume encoding:** 0-100 unmuted, 128-228 muted (byte - 128 = actual volume)
- **Source byte:** Packed bitfield — bit 7 = power, bit 6 = inverse L/R, bits 5-4 = standby mode, bits 3-0 = input source
- **Standby management:** Use "never" standby while awake; switch to 20-minute standby before sleep/power-off
- **Quirk:** Power off with 20-minute standby crashes the speaker — always switch to 60-minute standby before powering off

## Testing

- Protocol and command modules: unit tests with mock TCP connection (protocol-based dependency injection via SpeakerConnection)
- Controller logic: unit tests with mocked connection layer
- Hardware verification: manual testing against a real speaker
- Run all tests: `swift test --disable-sandbox`

## Git workflow

- Commit when a unit of work is done.
- **Push once, at the end of each turn**, after all work (sub-agents too) is finished. Never push mid-work: it interrupts the flow. The push asks Dileepa's permission, and that prompt is the gate.
- Use **Conventional Commits** syntax (e.g. `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`).
- **Branches:** `main` holds the released app. Work branches off `main` and merges back through a PR.

## Planning

This repo has issues switched off. Work items, plans and the agent-skill setup live outside it, and load through a gitignored `CLAUDE.local.md`.
