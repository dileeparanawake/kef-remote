# kef-remote

A native macOS background app for controlling KEF wireless speakers
(LS50 Wireless and LSX) via keyboard shortcuts with a floating HUD overlay.

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
- **Background agent** — No dock icon, no menu bar; runs invisibly

## Requirements

- macOS 14 (Sonoma) or later
- Accessibility permission (for media key interception)
- KEF LS50 Wireless or LSX speaker on the same network

## Building

```bash
swift build --disable-sandbox
```

## Running

```bash
swift run --disable-sandbox KEFRemote
```

On first launch, the app will prompt for Accessibility permission. Grant it
in System Settings > Privacy & Security > Accessibility.

Re-launch the app while running to open the settings window.

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

68 unit tests cover protocol encoding, volume/source codecs, and speaker
controller operations using a mock TCP connection.

## Credits

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
  by Sindre Sorhus (MIT License) — configurable global keyboard shortcuts
- [kefctl](https://github.com/adetaylor/kefctl) — Perl reference
  implementation (Artistic License 2.0) for KEF speaker protocol details

## License

MIT
