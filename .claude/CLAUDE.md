# CLAUDE.md

Guidance for Claude Code agents working on this repository.

## Project Overview

kef-remote is a native macOS app for controlling KEF wireless speakers
(LS50 Wireless and LSX) over TCP. It runs as a background agent
(LSUIElement=true) with no dock or menu bar icon, intercepting media
keys and providing a HUD overlay for volume/source feedback.

The codebase is structured as a Swift package with two targets:

- **KEFRemoteCore** (library) — All testable protocol, command, and
  controller logic. No UI, no system frameworks beyond Foundation.
- **KEFRemote** (executable, added later) — macOS app with HUD overlay,
  hotkey interception, settings window, and system integration.

## Tech Stack

- **Language:** Swift
- **Runtime:** Native macOS (minimum macOS 14 / Sonoma)
- **Build system:** Swift Package Manager + Xcode project
- **Testing:** `swift test --disable-sandbox` with Swift Testing framework
- **Networking:** Network.framework (NWConnection with TCP_NODELAY)
- **SSID detection:** CoreWLAN
- **Hotkeys:** KeyboardShortcuts (Sindre Sorhus, MIT) for power/quit;
  CGEvent tap for intercepting volume/mute media keys with Control modifier

## Building and Running

- **Build and run:** `open KEFRemote.xcodeproj` then Cmd+B / Cmd+R
- **Do NOT use `xed .`** when the xcodeproj exists (opens SPM package
  instead of the Xcode project)
- **Edit code:** Cursor + Claude CLI (not Xcode)
- **Run tests:** `swift test --disable-sandbox` (SPM, unchanged)
- **Signing:** Automatic, personal development team, sandbox disabled

## Project Structure

- `Package.swift` — Swift package manifest (two targets)
- `KEFRemote.xcodeproj/` — Xcode project for bundling, signing, running
- `Sources/KEFRemoteCore/` — Core library (protocol, commands, controller)
- `Sources/KEFRemote/` — macOS app (UI, hotkeys, lifecycle, integration)
- `Sources/KEFRemote/Info.plist` — App metadata (bundle ID, LSUIElement)
- `Sources/KEFRemote/KEFRemote.entitlements` — Permission declarations
- `Tests/KEFRemoteCoreTests/` — Unit tests for core library
- `resources/docs/plans/` — Design documents (git-ignored)
- `resources/docs/decisions/` — Architecture decision records (git-ignored)
- `~/.kef-remote/config.json` — User config (speaker IP, MAC, preferences)

## KEF Speaker Protocol

- **Connection:** TCP on port 50001
- **Commands:** GET is 3 bytes, SET is 4 bytes, sent/received over raw TCP
- **Registers:** 0x25 (volume), 0x30 (source/power/standby)
- **Volume encoding:** 0-100 unmuted, 128-228 muted (byte - 128 = actual volume)
- **Source byte:** Packed bitfield — bit 7 = power, bit 6 = inverse L/R,
  bits 5-4 = standby mode, bits 3-0 = input source
- **Standby management:** Use "never" standby while awake; switch to
  20-minute standby before sleep/power-off
- **Quirk:** Power off with 20-minute standby crashes the speaker —
  always switch to 60-minute standby before powering off

## Testing

- Protocol and command modules: unit tests with mock TCP connection
  (protocol-based dependency injection via SpeakerConnection)
- Controller logic: unit tests with mocked connection layer
- Hardware verification: manual testing against a real speaker
- Run all tests: `swift test --disable-sandbox`

## Learning Goals

This project is also a learning vehicle. The user is:

- Building understanding of systems-level programming (TCP, protocols,
  byte manipulation, network discovery) — coming from a web development
  background
- Learning architectural patterns and trade-offs beyond web apps
- Exploring agentic AI development workflows with Claude Code CLI
- Developing skills relevant to full-stack engineering hiring

Agents should explain concepts concretely, surface learning gaps, and
help the user understand *why* things work the way they do — not just
build the thing. See the user's global preferences for detailed guidance
on learning style.

## Current Status

### Implementation Complete (Tasks 1-23)

**Core library (KEFRemoteCore):**
- KEF command encoding/decoding (GET/SET byte commands)
- Volume byte codec (0-100 unmuted, 128-228 muted)
- Source byte bitfield codec (power, inverse, standby, input)
- SpeakerConnection protocol + MockSpeakerConnection for testing
- SpeakerController: volume, mute, power, input, standby, status ops
- AppConfig model with JSON persistence
- TCPSpeakerConnection using Network.framework
- SSDP speaker discovery with response parsing
- 68 tests passing across 6 suites

**macOS app (KEFRemote):**
- Background agent shell (no dock icon, SwiftUI + AppDelegate)
- HUD overlay (NSPanel floating display with fade animations)
- Media key interception (CGEvent tap with Control modifier)
- Power hotkeys (Cmd+Shift+O/P/Q via KeyboardShortcuts)
- Wake/sleep lifecycle hooks with delayed power-off
- SSID-based network monitoring (active/dormant state)
- SwiftUI settings window (tabbed, all config options)
- Full integration wiring in AppDelegate

### Xcode Project Setup (chore/xcode-setup branch)
- KEFRemote.xcodeproj with proper bundling, signing, entitlements
- Info.plist (LSUIElement, bundle ID, deployment target)
- KEFRemote.entitlements (get-task-allow for debugging)
- App builds and runs, speaker communication confirmed

### Known Issues
- TCP command serialisation: concurrent volume commands interleave on
  the wire, causing flaky HUD and incorrect volume values
- Config decoding: UInt8 enums need string-based Codable for readable
  config files
- SSID always nil: needs Location Services permission on macOS 14+
- See: `resources/docs/plans/2026-03-03-config-and-runtime-fixes.md`

### Next
- Fix TCP command serialisation (highest impact)
- Add string-based Codable for config enums
- Add Location Services for SSID detection
- Add missing test coverage

### Context
- Design doc: `resources/docs/plans/2026-02-28-kef-remote-design.md`
- Decisions: `resources/docs/decisions/2026-02-28-design-decisions.md`
- Implementation plan: `resources/docs/plans/2026-02-28-kef-remote-implementation.md`
- Xcode setup: `resources/docs/plans/2026-03-03-xcode-project-setup.md`
- Follow-up: `resources/docs/plans/2026-03-03-config-and-runtime-fixes.md`

## Git Workflow

- **Always ask for user confirmation before making any commit.**
- Use **Conventional Commits** syntax (e.g. `feat:`, `fix:`, `docs:`,
  `chore:`, `refactor:`, `test:`).
