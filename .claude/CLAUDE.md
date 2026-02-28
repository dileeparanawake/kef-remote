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
- **Runtime:** Native macOS (minimum macOS 13 / Ventura)
- **Build system:** Swift Package Manager
- **Testing:** `swift test --disable-sandbox` with XCTest
- **Networking:** Network.framework (NWConnection with TCP_NODELAY)
- **SSID detection:** CoreWLAN
- **Hotkeys:** KeyboardShortcuts (Sindre Sorhus, MIT) for power/quit;
  CGEvent tap for intercepting volume/mute media keys with modifier

## Project Structure

- `Package.swift` — Swift package manifest (two targets)
- `Sources/KEFRemoteCore/` — Core library (protocol, commands, controller)
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

### Done
- All-Swift design approved (single-process macOS app)
- Architecture decisions documented
- Swift package initialized with KEFRemoteCore library and test targets
- Implementation plan created

### Next
- Implement core protocol layer (command encoding, volume/source codecs)
- Build SpeakerConnection protocol and mock for testing
- Implement SpeakerController with TDD

### Context
- Design doc: `resources/docs/plans/2026-02-28-kef-remote-design.md`
- Decisions: `resources/docs/decisions/2026-02-28-design-decisions.md`
- Implementation plan: `resources/docs/plans/2026-02-28-kef-remote-implementation.md`

## Git Workflow

- **Always ask for user confirmation before making any commit.**
- Use **Conventional Commits** syntax (e.g. `feat:`, `fix:`, `docs:`,
  `chore:`, `refactor:`, `test:`).
