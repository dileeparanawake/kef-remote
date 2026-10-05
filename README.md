# KEF Remote

A small macOS app that puts a KEF LSX speaker on your keyboard. Hold Control and press the volume keys, and the speaker's volume changes instead of the Mac's, with an on-screen display like the one macOS shows for its own volume. Two more shortcuts turn the speaker on and off.

It runs in the background with no Dock icon. A small speaker icon in the menu bar shows it's running, and opens Settings.

This is an early release with real rough edges. Read [Known limitations](#known-limitations) before you install it.

## Requirements

- macOS 14 (Sonoma) or later.
- A KEF LSX on the same network as your Mac.
- Accessibility permission, so the app can see the volume keys.

I've only tested it on an original LSX. The LS50 Wireless uses the same control protocol, so it may work, but I haven't tried one. Newer models such as the LSX II and LS50 Wireless II use a different control system and aren't supported.

## Install

### 1. Download

Download the zip from the [Releases](https://github.com/dileeparanawake/kef-remote/releases) page, unzip it by double-clicking it in Finder, and move `KEFRemote.app` to your Applications folder.

### 2. Tell it where the speaker is

KEF Remote can't find the speaker by itself yet, so you give it the speaker's IP address before you open it.

To find the IP, look in KEF's own app on your phone: it shows the speaker's IP in the speaker's settings while it's connected. Or open your router's admin page and look at its list of connected devices for one named LSX or KEF. While you're there, reserve that IP for the speaker (routers often call this a DHCP reservation), because KEF Remote won't notice if the speaker's IP changes.

Then copy the block below into Terminal. First change the IP on the first line to your speaker's: open a text editor, paste the block, edit the first line, then copy it into Terminal. It works in zsh, the macOS default shell; if you use another shell, such as fish, type `zsh` first.

```sh
KEF_IP=192.168.1.50
mkdir -p ~/.kef-remote
cat > ~/.kef-remote/config.json <<EOF
{
  "app": { "launchAtLogin": false },
  "defaults": { "input": 11, "standby": 2 },
  "lifecycle": { "powerOffDelay": 60, "powerOffSleep": false, "powerOnWake": false },
  "network": {},
  "speaker": { "lastKnownIp": "$KEF_IP" }
}
EOF
plutil -extract speaker.lastKnownIp raw ~/.kef-remote/config.json && echo "Saved. If KEF Remote is open, quit it (Cmd+Shift+Q) and open it again."
```

It prints the IP it saved, then "Saved". If you see an error instead, the file isn't valid: run the block again.

**The app reads this file only when it starts.** After any change, quit KEF Remote (Cmd+Shift+Q) and open it again.

### 3. Open it the first time

#### macOS 15 (Sequoia) and later

1. Open `KEFRemote.app`. macOS says it wasn't opened. Click Done.
2. Open System Settings > Privacy & Security and scroll down to Security.
3. Click Open Anyway. It only shows for about an hour after the blocked open.
4. Enter your password, then click Open.

#### macOS 14 (Sonoma)

Control-click `KEFRemote.app` in Finder, choose Open, then click Open.

#### Any version, from Terminal

Remove the quarantine flag macOS adds to downloads, and it opens normally:

```sh
xattr -dr com.apple.quarantine /Applications/KEFRemote.app
```

You only need to do this once. If it says "No such xattr", the flag is already gone.

### 4. Allow Accessibility

On first open, macOS asks to give KEF Remote Accessibility access. Open System Settings from the prompt and turn KEFRemote on under Privacy & Security > Accessibility.

Then quit KEF Remote (Cmd+Shift+Q) and open it again. It only starts listening for the volume keys at launch, so the permission takes effect after a restart.

### 5. Allow local network access

On macOS 15 and later, macOS asks whether KEF Remote can find and connect to devices on your local network. Click Allow, or it can't reach the speaker. If you missed the prompt, turn it on in System Settings > Privacy & Security > Local Network.

### 6. Check it's running

A speaker icon appears in the menu bar. Click it to see the speaker's status. Then press Cmd+Shift+O to turn the speaker on, then Control + volume up: a small panel in the middle of the screen shows the volume. If nothing happens, check the IP (step 2) and that you reopened the app after granting Accessibility (step 4).

## Shortcuts

| Shortcut | What it does |
|---|---|
| Control + Volume Up (F12) | Speaker volume up by 5 |
| Control + Volume Down (F11) | Speaker volume down by 5 |
| Control + Mute (F10) | Mute or unmute the speaker |
| Cmd + Shift + O | Turn the speaker on |
| Cmd + Shift + P | Turn the speaker off |
| Cmd + Shift + Q | Quit KEF Remote |

If your function keys are set to work as standard F keys, hold Fn as well for the volume keys.

Cmd+Shift+Q is also the macOS shortcut for Log Out. While KEF Remote is running it should get the shortcut first. If macOS asks whether you want to log out instead, click Cancel and quit KEF Remote from Activity Monitor.

To use a different key from Control, or change the shortcuts, open Settings from the menu bar icon. Changes apply straight away.

## Menu bar icon

The icon shows whether KEF Remote is connected to the speaker. It checks when it starts, and every key press updates it.

| Icon | Meaning |
|---|---|
| Filled speaker | Connected: the speaker answered |
| Speaker outline | Checking the speaker answers |
| Speaker with a warning badge | Not connected: the speaker didn't answer |
| Magnifying glass | Looking for the speaker |
| Speaker with a plus | No speaker set |
| Crossed-out speaker | Paused: not on the home network |

The menu's first line says "Connected to LSX" or "Not connected", with the IP or the reason under it. When it isn't connected, Find speaker looks for the speaker on the network and saves its IP. Settings… and Quit are below.

## Known limitations

| Limitation | What to do for now |
|---|---|
| It can't find the speaker on the network by itself. | Set the speaker's IP in `~/.kef-remote/config.json` (see [Install](#2-tell-it-where-the-speaker-is)). |
| If the speaker's IP changes, it keeps trying the old one. | Reserve an IP for the speaker in your router, or update the config and restart. |
| It doesn't start at login. | Add it in System Settings > General > Login Items. |
| Fast repeated key presses can get lost. After an error, presses are ignored for about two seconds while it reconnects. | Press the keys one at a time. |
| Turning the speaker on at wake and off at sleep is in the code, but off by default and untested. | Leave `powerOnWake` and `powerOffSleep` set to `false`. |

## Build from source

You'll need Xcode on macOS 14 or later.

1. Clone this repo and open `KEFRemote.xcodeproj` in Xcode.
2. In the KEFRemote target's Signing & Capabilities, choose your own team. If Xcode rejects the bundle identifier, change it to something unique.
3. Press Cmd+R to build and run.

Run the tests with:

```sh
swift test --disable-sandbox
```

There are 97 unit tests. They cover the protocol encoding, the volume and source bytes, the config file, and the speaker commands against a mock connection. Everything that touches the real speaker, the keys or the display was tested by hand.

## How it works

The app talks to the speaker over TCP on port 50001, the protocol the KEF Control app uses. Volume and mute live in one register, and power, input and standby are packed into the bits of another.

The code is a Swift package with two targets:

- **KEFRemoteCore**: the protocol, speaker commands, TCP connection and config, with no UI.
- **KEFRemote**: the macOS app, with volume key interception, the on-screen display and the shortcuts.

## Credits

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus (MIT License), for the global shortcuts.
- [kefctl](https://github.com/kraih/kefctl), a Perl reference implementation (Artistic License 2.0), for the details of the KEF speaker protocol.

## Licence

MIT. See [LICENSE](LICENSE).
