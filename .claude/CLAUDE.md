# KEF Remote

Native macOS app for controlling KEF wireless speakers (LS50 Wireless and LSX) over TCP. Runs as a background agent (LSUIElement=true) with no Dock icon, except while one of its windows is open (`OpenWindows`), so a window behind another app's can be found again. A menu bar icon shows whether the speaker is connected (it answered the last exchange), with a red dot when something needs the user, a brief green dot on connecting and a pulsing orange dot while it looks for the speaker. It offers Find speaker when it isn't connected, turns the speaker on or off as its label says, with the turn-on defaults (`PowerMenuItem` → `PowerMenuAction`), switches the input now (Input ▸, `InputMenu`, ticked from the last source byte), reads that byte again as the menu or Settings opens (`SourceByteRefresh`, `MenuOpenWatcher`), opens Permissions and Settings (plain `NSWindow`s; Settings in Speaker, Keys and About tabs, `SettingsTab`; its Speaker rows show what the speaker has now, `SpeakerNow`), links to who made it (`MenuLink`; Support stays hidden until its page exists), and offers Send feedback… (`FeedbackEmail`, to Dileepa's Gmail). A setup window (`Onboarding/`: 1 Permissions, 2 Find your speaker, 3 You're set) opens at launch until it's finished (`"onboarding": {"finished": true}` in config.json); after that, only its permissions step opens, at launch while Accessibility is missing and from Permissions…. Until it's finished, the menu's first item is Finish setup…, and the Dock icon opens it too, on the step he left (`SetupWindowOpening`). It intercepts the volume keys (volume up, down and mute, with the modifier held; play/pause, next and previous stay the Mac's) and shows a HUD overlay for volume/source feedback. Menu and settings actions log under the `menubar` and `settings` categories; permission changes under `permissions`; the setup window's steps and clicks under `onboarding`.

## Codebase

Four targets in a Swift package, plus tests:

- **KEFRemoteCore** (library) — Testable protocol, command, and controller logic. No UI, no system frameworks beyond Foundation and Network.
- **KEFRemoteCore** folders: `Protocol/` (byte encoding), `Commands/` (`SpeakerController`, the connection check), `Connection/` (TCP, reply timeout), `Config/` (`config.json`, Auto/Manual discovery), `Discovery/` (SSDP), `Logging/`, `MenuBar/` and `HUD/` (what the icon, menu and HUD show), `Settings/` (the Settings tabs, the app version), `Network/` (home-network rule, Local Network permission, its retry while blocked and its checks while setup is open), `Permissions/` (each permission's row in the guide, its System Settings URL, the volume keys line: ready, restart, or starts on the home network), `Onboarding/` (the setup steps, what unlocks Continue, the finished flag, what opens at launch and from the menu and Dock, step 2's search line, that the app's own searches wait for step 2, which looks as it shows), `Windows/` (which windows are open, so whether the Dock icon shows; how one comes to the front, held back after the macOS prompt), `Shortcuts/` (what each global shortcut does, and that they pause while any of the app's menus is open), `Check/` (the speaker check: each step, read-back and putting the start back; a simulated speaker for its dry run and tests), `Utilities/`.
- **KEFRemote** (executable) — macOS app: HUD overlay (`UI/`), media keys and global shortcuts, wake/sleep and Wi-Fi watching (`Control/`), menu bar (`MenuBar/`), settings window (`Settings/`), permissions guide (`Permissions/`), setup window that hosts it as step 1 (`Onboarding/`), logging to file (`Logging/`). `AppDelegate` wires them together.
- **kef-discover** (executable) — runs discovery once and prints each step (`make discover`).
- **kef-check** (executable) — runs every speaker command on the saved IP, reads each back, puts the start back (`make speaker-check`).

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
| `make speaker-check` | Run every speaker command, read each back, put the start back (`INPUTS=1` each input, `DRY_RUN=1` simulated). Changes what's playing: only when Dileepa is away; quit the app first |
| `make app-icon` | Redraw the app icon PNGs from `Design/AppIcon.svg` |
| `make run` | Launch most recently built debug app |
| `make test-build` | Quit the running app, build this branch as the one test app (`…KEFRemote.test`, fixed path in `~/Library/Developer/KEFRemoteTest`) and launch it |
| `make test-fresh` | Hand test from a clean slate: config aside, test app's preferences cleared, then `test-build`. Changes no privacy setting |
| `make test-clean` | Prints how to remove the test app's privacy entries |
| `make test-restore` | Put back what `test-fresh` saved |
| `make package` | Zip the latest Release build into `dist/KEFRemote-<version>.zip` (`ditto --norsrc --keepParent`) |
| `make kill` | Stop all running KEFRemote instances |
| `make logs-recent` | Last 200 lines from log file (quick agent snapshot) |
| `make logs-previous` | The run before this one (each launch moves the last run's log to `kef-remote.previous.log`) |
| `make logs-tail` | Live stream from log file |
| `make logs-previous` | The run before this one (`kef-remote.previous.log`) |
| `make logs-errors` | Errors only, from the log file |
| `make logs-warnings` | Warnings and errors, from the log file |
| `make logs-debug` | Debug lines (bytes on the wire), from the log file |
| `make logs-stream` | Unified logging stream (standalone app, interactive terminal only) |
| `make logs-stream-debug` | Unified logging, full trace (standalone app, interactive terminal only) |
| `make logs-stream-errors` | Unified logging, errors only (standalone app, interactive terminal only) |
| `make kef-on/off/status` | Hardware control via kefctl (for manual testing) |
| `make kef-raw-volume VOL=70` | Set volume directly via kefctl |

## Project structure

- `Package.swift` — Swift package manifest (four targets, one test target)
- `KEFRemote.xcodeproj/` — Xcode project for bundling, signing, running
- `Sources/KEFRemoteCore/` — Core library (protocol, commands, controller)
- `Sources/KEFRemote/` — macOS app (UI, hotkeys, lifecycle, integration)
- `Sources/KEFRemote/Info.plist` — App metadata (bundle ID, LSUIElement)
- `Sources/KEFRemote/Assets.xcassets/` — App icon (`AppIcon`), drawn from `Design/AppIcon.svg` by `make app-icon`
- `Design/` — Icon source SVG and the script that renders it
- `Sources/KEFRemote/KEFRemote.entitlements` — Permission declarations
- `Tests/KEFRemoteCoreTests/` — Unit tests for core library
- `~/.kef-remote/config.json` — User config (speaker IP, MAC, `discovery`: `auto` or `manual`, `onboarding.finished`, `onboarding.resumeAtFindSpeaker` (set by Restart and continue, cleared once step 2 shows), preferences). Shortcuts are saved by KeyboardShortcuts in UserDefaults

## KEF speaker protocol

- **Connection:** TCP on port 50001
- **Commands:** GET sends 3 bytes, receives 5 bytes; SET sends 4 bytes, receives 3 bytes (ack)
- **Registers:** 0x25 (volume), 0x30 (source/power/standby)
- **Playback (0x31):** not used. The speaker acks play/pause, next and previous, but nothing plays or pauses on Wi-Fi, Bluetooth or AirPlay, and KEF's own remote does the same (hand test round 6), so 0.3.0 leaves the play keys to the Mac
- **Volume encoding:** 0-100 unmuted, 128-228 muted (byte - 128 = actual volume)
- **Source byte:** Packed bitfield — bit 7 = power, bit 6 = inverse L/R, bits 5-4 = standby mode, bits 3-0 = input source
- **Standby management:** Settings' standby time is set on connect, when chosen and in the power-on write. On wake use the chosen time ("never" if Don't change); switch to 20-minute standby before sleep/power-off. Never write 20 minutes to a speaker that is off
- **Quirk:** Power off with 20-minute standby crashes the speaker — always switch to 60-minute standby before powering off

## Testing

- Protocol and command modules: unit tests with mock TCP connection (protocol-based dependency injection via SpeakerConnection)
- Controller logic: unit tests with mocked connection layer
- Hardware verification: manual testing against a real speaker
- Run all tests: `swift test --disable-sandbox`

## Code quality checklist

Check every change against these before committing.

**Testable**
- [ ] New logic (decisions, parsing, mapping) lives in `KEFRemoteCore`, not the app target.
- [ ] It takes its dependencies (connection, socket, log, clock) through a protocol or closure, and has tests.

**Debuggable**
- [ ] Each command, decision and failure logs one plain line, with the reason; nothing fails silently.
- [ ] Bytes on the wire log at `.debug`; `make logs-recent` / `logs-errors` show what happened.

**Modular and extendable**
- [ ] One job per type; app classes only watch the system and fire callbacks.
- [ ] No copy-paste: a third copy becomes a helper.

**Readable**
- [ ] Names say what a thing is or does (`getSourceByte`, not `getPowerState`); no aliases or dead code.
- [ ] Comments say why, and match the code; no magic numbers.
- [ ] `swift test --disable-sandbox` passes and a Debug `xcodebuild` builds with no new warnings.

## Git workflow

- Commit when a unit of work is done.
- **Push once, at the end of each turn**, after all work (sub-agents too) is finished. Never push mid-work: it interrupts the flow. The push asks Dileepa's permission, and that prompt is the gate.
- Use **Conventional Commits** syntax (e.g. `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`).
- **Branches:** `main` holds the released app. Work branches off `main` and merges back through a PR.

## Planning

This repo has issues switched off. Work items, plans and the agent-skill setup live outside it, and load through a gitignored `CLAUDE.local.md`.
