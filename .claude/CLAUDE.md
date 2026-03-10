# KEF Remote

Native macOS app for controlling KEF wireless speakers (LS50 Wireless and LSX) over TCP. Runs as a background agent (LSUIElement=true) with no dock or menu bar icon, intercepting media keys and providing a HUD overlay for volume/source feedback.

## Codebase

Two targets in a Swift package:

- **KEFRemoteCore** (library) — Testable protocol, command, and controller logic. No UI, no system frameworks beyond Foundation.
- **KEFRemote** (executable) — macOS app with HUD overlay, hotkey interception, settings window, and system integration.

**Tech stack:** Swift, macOS 14+, SPM + Xcode project, Network.framework (TCP), CoreWLAN, KeyboardShortcuts, CGEvent tap, Swift Testing.

## Building and running

- **Build and run:** `open KEFRemote.xcodeproj` then Cmd+B / Cmd+R
- **Do NOT use `xed .`** when the xcodeproj exists (opens SPM package instead)
- **Edit code:** Cursor + Claude CLI (not Xcode)
- **Run tests:** `swift test --disable-sandbox`
- **Signing:** Automatic, personal development team, sandbox disabled

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
- **Commands:** GET is 3 bytes, SET is 4 bytes, sent/received over raw TCP
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

- **Always ask for user confirmation before making any commit.**
- Use **Conventional Commits** syntax (e.g. `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`).

## Project context

Project status, plans, decisions, and learnings are tracked in the context repo:

- **Status:** `~/coding/projects/context-engineering/projects/kef-remote-context/status.md`
- **Plans:** `~/coding/projects/context-engineering/projects/kef-remote-context/plans/`
- **Decisions:** `~/coding/projects/context-engineering/projects/kef-remote-context/decisions/`
- **Learnings:** `~/coding/projects/context-engineering/projects/kef-remote-context/learnings/`

- **Learning goals:** `~/coding/projects/context-engineering/projects/kef-remote-context/learnings/learning-goals.md`

Read the status file to understand where the project stands before starting work.
