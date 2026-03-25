# kef-remote

A native macOS app for controlling KEF LSX speakers
via keyboard shortcuts with a floating HUD overlay.

**Status:** v1 redesign in progress. See `context/plans/v1/` for design and build plans.

## Features (planned for v1)

- **Media key control** — Hold modifier + press Volume Up/Down/Mute to control
  the KEF speaker instead of system volume
- **Power toggle** — Configurable keyboard shortcut to toggle speaker power
- **HUD overlay** — Floating translucent display showing volume, mute, and
  power status with optimistic and confirmed feedback
- **Menu bar** — Connection status indicator, settings access, quit
- **SSDP discovery** — Automatically finds speakers on the local network
- **Background agent** — No dock icon; menu bar icon for status and settings

## Requirements

- macOS 14 (Sonoma) or later
- Accessibility permission (for media key interception)
- KEF LSX speaker on the same network

## Building and running

Build in Xcode (`open KEFRemote.xcodeproj`, then Cmd+B), then launch with:

```bash
make run     # launch most recently built debug app
make kill    # stop all running instances
make test    # run test suite
```

On first launch, grant Accessibility permission in System Settings > Privacy & Security > Accessibility.
Re-launch the app while it is running to open the settings window.

### Other useful Makefile targets

```bash
make logs-recent   # last 200 lines from log file (quick agent snapshot)
make logs-tail     # live stream from log file
make logs-debug    # full trace including bytes on the wire (standalone only)
make kef-on        # power speaker on via kefctl (hardware testing)
make kef-status    # check speaker state via kefctl
```

## Configuration

Settings are stored at `~/.kef-remote/config.json`. Use the settings window
to configure:

- Speaker IP address (or use auto-discovery)
- Default input source and standby timeout
- Wake/sleep behavior and power-off delay
- Home network SSID
- Keyboard shortcuts

## Architecture

Built as a Swift package with two targets:

- **KEFRemoteCore** — Testable library: logging, protocol encoding, speaker
  communication, state model, command coalescing
- **KEFRemote** — macOS app: HUD overlay, keyboard interception, settings
  window, lifecycle hooks, menu bar

Five architectural layers: Infrastructure, Speaker Communication, Application,
Input, UI. See `context/plans/v1/design.md` for the full design.

## Testing

```bash
make test
```

Three levels: isolation (unit tests with injectable mocks), integration
(boundary tests), manual (hardware verification against a real speaker).

## Credits

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
  by Sindre Sorhus (MIT License) — configurable global keyboard shortcuts
- [kefctl](https://github.com/adetaylor/kefctl) — Perl reference
  implementation (Artistic License 2.0) for KEF speaker protocol details

## License

MIT
