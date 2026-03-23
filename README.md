# kef-remote

A native macOS background app for controlling KEF LSX speakers
via keyboard shortcuts with a floating HUD overlay.

## Features

- **Media key control** — Hold Shift + press Volume Up/Down/Mute to control
  the KEF speaker instead of system volume
- **Power shortcuts** — Cmd+Shift+O to power on, Cmd+Shift+P to power off
- **HUD overlay** — Floating translucent display showing volume, mute, and
  power status (similar to macOS native OSD)
- **Wake/sleep integration** — Automatically power on speakers when Mac wakes,
  power off after configurable delay when Mac sleeps
- **Network awareness** — Only active on your home Wi-Fi network (SSID-based)
- **SSDP discovery** — Automatically finds speakers on the local network
- **Background agent** — No dock icon; runs invisibly with a menu bar icon for status and settings

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

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Shift + Volume Up | Raise KEF volume |
| Shift + Volume Down | Lower KEF volume |
| Shift + Mute | Toggle KEF mute |
| Cmd+Shift+O | Power on |
| Cmd+Shift+P | Power off |
| Cmd+Shift+Q | Quit |

The modifier key (default: Shift) and power/quit shortcuts are configurable
in settings.

## Architecture

Built as a Swift package with two targets:

- **KEFRemoteCore** — Testable library with protocol encoding, speaker
  controller, config model, TCP connection, and SSDP discovery
- **KEFRemote** — macOS app with HUD overlay, hotkey interception, settings
  window, lifecycle hooks, and network monitoring

KEF speakers communicate over TCP on port 50001 using 3-4 byte hex commands.
The protocol uses two registers: 0x25 (volume) and 0x30 (source/power/standby).

## Testing

```bash
swift test --disable-sandbox
```

97 unit tests cover protocol encoding, volume/source codecs, and speaker
controller operations using a mock TCP connection.

## Credits

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
  by Sindre Sorhus (MIT License) — configurable global keyboard shortcuts
- [kefctl](https://github.com/adetaylor/kefctl) — Perl reference
  implementation (Artistic License 2.0) for KEF speaker protocol details

## License

MIT
