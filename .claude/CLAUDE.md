# KEF Remote

Native macOS app for controlling KEF LSX speakers over TCP. Runs as a background agent (LSUIElement=true) with no dock icon, intercepting media keys and providing a HUD overlay for volume/source feedback. Menu bar icon planned as a core v1 feature.

## Codebase

Two targets in a Swift package:

- **KEFRemoteCore** (library) — Testable protocol, command, and controller logic. No UI, no system frameworks beyond Foundation.
- **KEFRemote** (executable) — macOS app with HUD overlay, hotkey interception, settings window, and system integration.

**Tech stack:** Swift, macOS 14+, SPM + Xcode project, Network.framework (TCP), CoreWLAN, KeyboardShortcuts, CGEvent tap, Swift Testing.

## Building and running

- **Build:** `open KEFRemote.xcodeproj` then Cmd+B / Cmd+R
- **Do NOT use `xed .`** when the xcodeproj exists (opens SPM package instead)
- **Edit code:** Cursor + Claude CLI (not Xcode)
- **Signing:** Automatic, personal development team, sandbox disabled

## Makefile

Use `make <target>` for common operations. Key targets:

| Target | Purpose |
|--------|---------|
| `make test` | Run test suite (`swift test --disable-sandbox`) |
| `make run` | Launch most recently built debug app |
| `make kill` | Stop all running KEFRemote instances |
| `make logs-recent` | Last 200 lines from log file (quick agent snapshot) |
| `make logs-tail` | Live stream from log file |
| `make logs` | Unified logging stream (standalone only) |
| `make logs-debug` | Full trace including bytes on the wire (standalone only) |
| `make logs-errors` | Errors only |
| `make kef-on/off/status` | Hardware control via kefctl (for manual testing) |
| `make kef-raw-volume VOL=70` | Set volume directly via kefctl |
| `make context-status/diff/log` | Git operations on the context repo |
| `make metrics-tokens` | Extract token usage from JSONL session logs |

## Project structure

- `Package.swift` — Swift package manifest (two targets)
- `KEFRemote.xcodeproj/` — Xcode project for bundling, signing, running
- `Sources/KEFRemoteCore/` — Core library (protocol, commands, controller)
- `Sources/KEFRemote/` — macOS app (UI, hotkeys, settings, system integration)
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
- **Standby management:** Use "never" standby while awake; switch to 20-minute standby before sleep
- **Quirk:** Power off with 20-minute standby crashes the speaker — always switch to 60-minute standby before powering off
- **Full protocol reference:** `~/coding/projects/context-engineering/projects/kef-remote-context/plans/v1/references/protocol.md`

## Testing

- All concerns are tested via injectable dependencies (protocol-based dependency injection)
- Three levels: isolation (unit tests), integration (boundary tests), manual (hardware verification)
- Run all tests: `swift test --disable-sandbox`

## Git workflow

- **Always ask for user confirmation before making any commit.**
- Use **Conventional Commits** syntax (e.g. `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`).

### context/ is a symlink — separate git repo

`context/` in this project is a symlink to the context-engineering repo at
`~/coding/projects/context-engineering/projects/kef-remote-context/`.

Changes to any file under `context/` (status, design, plans, references, etc.) must be
committed to the context repo, **not** to kef-remote. Commit context changes first,
before committing any related kef-remote changes.

Use the Makefile targets to work with the context repo:

```bash
make context-status   # git status of context repo
make context-diff     # git diff of context repo
make context-add      # git add -A in context repo
make context-commit MSG="docs: update v1 design"
make context-log      # recent commits in context repo
```

## Project context

Project status, plans, decisions, and learnings are tracked in the context repo:

- **Status:** `~/coding/projects/context-engineering/projects/kef-remote-context/status.md`
- **Plans:** `~/coding/projects/context-engineering/projects/kef-remote-context/plans/`
- **Decisions:** `~/coding/projects/context-engineering/projects/kef-remote-context/decisions/`
- **Learnings:** `~/coding/projects/context-engineering/projects/kef-remote-context/learnings/`
- **Learning goals:** `~/coding/projects/context-engineering/projects/kef-remote-context/learnings/learning-goals.md`

### v1 redesign (active)

- **v1 context:** `~/coding/projects/context-engineering/projects/kef-remote-context/plans/v1/context.md`
- **v1 status:** `~/coding/projects/context-engineering/projects/kef-remote-context/plans/v1/status.md`
- **v1 design:** `~/coding/projects/context-engineering/projects/kef-remote-context/plans/v1/design.md`
- **v1 references:** `~/coding/projects/context-engineering/projects/kef-remote-context/plans/v1/references/`
- **Friction log:** `~/coding/projects/context-engineering/projects/kef-remote-context/plans/v1/meta/learnings/friction-log.md`

Read the v1 status file before starting any work on the v1 branch. Log process friction
(blueprint vs reality mismatches, unclear boundaries) to the friction log.
