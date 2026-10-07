# KEF Remote

KEF already has an app, but I built this one to put my speaker on my keyboard. That matters most if you listen over optical for hi-res audio, like I do: the Mac's volume keys can't reach the speaker over optical, so it's back to the clunky remote. If you use AirPlay, the Mac's own volume already works.

KEF Remote is a small macOS app for the KEF LSX. Hold Control and press the volume keys, and the speaker's volume changes instead of the Mac's, with an on-screen display like the one macOS shows for its own volume. Cmd+Shift+O turns the speaker on, or off if it's on, and can switch it to optical as it does.

![KEF Remote: Control plus the volume up key shows a volume panel at 60% on screen, and the KEF speaker plays louder](docs/images/social-preview.png)

It runs in the background with no Dock icon. A small speaker icon in the menu bar shows whether it's connected to the speaker, and opens Settings.

This is an early release with real rough edges. Read [Known limitations](#known-limitations) before you install it.

## Requirements

- macOS 14 (Sonoma) or later.
- A KEF LSX on the same network as your Mac.
- Accessibility permission, so the app can see the volume keys.
- On macOS 15 and later, Local Network permission, so the app can find the speaker.

I've only tested it on an original LSX. The LS50 Wireless uses the same control protocol, so it may work, but I haven't tried one. Newer models such as the LSX II and LS50 Wireless II use a different control system and aren't supported.

## Install

Upgrading from 0.1.0? Read [Upgrading from 0.1.0](#upgrading-from-010) first.

### 1. Download

Download the zip from the [Releases](https://github.com/dileeparanawake/kef-remote/releases) page, unzip it by double-clicking it in Finder, and move `KEFRemote.app` to your Applications folder.

### 2. Open it the first time

macOS blocks the first open, because Apple hasn't checked (notarized) the app.

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

### 3. Allow the two permissions

When it opens, KEF Remote shows a small window with the two permissions it needs. Each has a button that opens System Settings, and gets a tick once it's allowed.

- **Accessibility**, so the volume keys reach the speaker. Click Open Settings, then turn on KEFRemote.
- **Local Network** (macOS 15 and later), so the app can find the speaker. macOS asks the first time the app looks for the speaker: click Allow. If you missed it, click Open Settings and turn on KEF Remote under Privacy & Security > Local Network. Its tick shows once the speaker answers.

To open the window again, click the speaker icon in the menu bar, then Permissions….

### 4. Check it's connected

When it opens, KEF Remote looks for the speaker on your network and saves its IP. Click the speaker icon in the menu bar. It should say "Connected to LSX".

Press Cmd+Shift+O to turn the speaker on. Then press Control + volume up. A small panel in the middle of the screen shows the volume. If nothing happens, quit KEF Remote from the menu bar icon and open it again.

If the icon has a red dot, the menu's first line says what's wrong and what to do. Usually it says "click Find speaker". Find speaker is in the same menu.

### If it can't find the speaker

Set the IP by hand:

1. Click the menu bar icon and choose Settings….
2. Under Speaker, set Discovery to Manual.
3. Type the speaker's IP and click Save.

In Manual, KEF Remote uses that IP and never looks for the speaker by itself. Switch back to Auto to let it find the speaker again.

To find the IP, look in KEF's own app on your phone: it shows the speaker's IP in the speaker's settings while it's connected. Or open your router's admin page and look at its list of connected devices for one named LSX or KEF.

The IP and the discovery mode are saved in `~/.kef-remote/config.json`.

### Upgrading from 0.2.0

1. Quit 0.2.0: click the speaker icon in the menu bar, then Quit KEF Remote.
2. Download the latest release (step 1) and replace `KEFRemote.app` in Applications.
3. Open it. If macOS blocks it, follow step 2.
4. If the permissions window shows Accessibility as not allowed while System Settings shows it on, turn KEFRemote off, then on again.

Your settings and config file carry over.

### Upgrading from 0.1.0

0.1.0 has no menu bar icon, so quit it another way.

1. Quit 0.1.0: press Cmd+Shift+Q, or quit KEFRemote in Activity Monitor.
2. Download the latest release (step 1) and replace `KEFRemote.app` in Applications.
3. Open it. If macOS blocks it, follow step 2.
4. If the volume keys don't respond, open System Settings > Privacy & Security > Accessibility. Turn KEFRemote off, then on again. Then quit KEF Remote and open it again.

Your config file from 0.1.0 keeps working, with discovery on Auto.

## What's new in 0.3.0

- **A permissions guide.** The first time it opens, a small window shows the two permissions it needs, opens the right page of System Settings, and ticks each one off.
- **Switch the input from the menu.** Input ▸ in the menu bar switches the speaker to Optical, Wi-Fi, Bluetooth, Aux or USB now.
- **Input when it turns on.** Choose the input, such as Optical, the speaker switches to when KEF Remote turns it on.
- **Standby time.** Choose 20 minutes, 60 minutes or never.
- **Swap left and right** in Settings, if your speakers are the other way round.
- **Made by Dileepa** in the menu, a link to my site.

## Set the speaker up

Under Speaker defaults in Settings, three settings set the speaker up for you. Input on turn-on and Standby start at Don't change, so KEF Remote leaves the speaker as it is until you pick something.

| Setting | What it does |
|---|---|
| Input on turn-on | The input the speaker switches to when KEF Remote turns it on: Optical, Wi-Fi, Bluetooth, Aux or USB. It doesn't apply when you turn it on with KEF's own remote, or if it's already on. |
| Standby | How long the speaker waits with no sound before it goes to standby: 20 min, 60 min or Never. KEF Remote sets it when you choose it, and each time it connects. |
| Swap left and right | Swaps which speaker plays the left channel. The switch shows how the speaker is set now, and changes it straight away. The speaker remembers it, so KEF Remote doesn't save it. It's greyed out while KEF Remote isn't connected. |

## Shortcuts

| Shortcut | What it does |
|---|---|
| Control + Volume Up (F12) | Speaker volume up by 5 |
| Control + Volume Down (F11) | Speaker volume down by 5 |
| Control + Mute (F10) | Mute or unmute the speaker |
| Cmd + Shift + O | Turn the speaker on, or off if it's on |
| Cmd + Shift + Q | Quit KEF Remote |

If your function keys are set to work as standard F keys, hold Fn as well for the volume keys.

Cmd+Shift+Q is also the macOS shortcut for Log Out. While KEF Remote is running it should get the shortcut first. If macOS asks whether you want to log out instead, click Cancel. Then quit from the menu bar icon: click it, then Quit KEF Remote.

To use a different key from Control, or change the shortcuts, open Settings from the menu bar icon. To change a shortcut, click its field and press the new keys; Delete clears it. Volume up, volume down and mute have no shortcut until you record one. Changes apply straight away.

## Menu bar icon

The icon shows whether KEF Remote is connected to the speaker. It checks when it starts, and every key press updates it.

| Icon | Meaning |
|---|---|
| Filled speaker | Connected: the speaker answered |
| Filled speaker, green dot | Just connected (the dot goes after 4 seconds) |
| Speaker outline | Checking the speaker answers |
| Speaker outline, pulsing orange dot | Looking for the speaker |
| Crossed-out speaker | Paused: not on the home network |
| Any of these, red dot | Needs you: the speaker didn't answer, no speaker is set, or a permission is off |

The red dot is a shape as well as a colour, so you can see it without colour vision.

The menu's first line says "Connected to LSX", with the IP under it. With a red dot it says what's wrong and what to do, such as "Can't reach LSX: click Find speaker" or "Volume keys off: allow Accessibility". Find speaker looks for the speaker on the network and saves its IP.

Input ▸ comes next. It ticks the input the speaker is on. Pick another and the speaker switches straight away, and the new input shows on screen. It's greyed out while KEF Remote isn't connected.

Below that are Permissions…, Settings…, a link to my site (Made by Dileepa) and Quit KEF Remote. Permissions… shows a tick when both permissions are allowed. When one is off, it says so, such as "Permissions… (1 needs you)".

## Known limitations

| Limitation | What to do for now |
|---|---|
| Finding the speaker needs the Mac and the speaker on the same network, with local network access allowed. | Set the IP in Settings (see [If it can't find the speaker](#if-it-cant-find-the-speaker)). |
| It doesn't start at login. | Add it in System Settings > General > Login Items. |
| Fast repeated key presses can get lost. After an error, presses are ignored for about two seconds while it reconnects. | Press the keys one at a time. |
| After the Mac sleeps, the icon can still say connected until the next key press. | Press a volume key; the icon updates. |
| Turning the speaker on at wake and off at sleep is in the code, but off by default and untested. | Leave `powerOnWake` and `powerOffSleep` set to `false` in the config file. |

## Build from source

You'll need Xcode on macOS 14 or later.

1. Clone this repo and open `KEFRemote.xcodeproj` in Xcode.
2. In the KEFRemote target's Signing & Capabilities, choose your own team. If Xcode rejects the bundle identifier, change it to something unique.
3. Press Cmd+R to build and run.

Run the tests with:

```sh
swift test --disable-sandbox
```

There are 418 unit tests. They cover the protocol encoding, the volume and source bytes, the config file, the speaker commands against a mock connection, the input, standby and swap settings, the permissions guide's rows, the reply timeout, discovery against a mock socket, the connection check, the menu bar's states and its Input menu, the shortcuts, the log file and the speaker check against a simulated speaker. Everything that touches the real speaker, the keys or the display was tested by hand.

To check a real speaker end to end, quit the app and run `make speaker-check` (add `INPUTS=1` for each input, or `DRY_RUN=1` to try it without the speaker): it runs every command, reads each back, and puts the speaker back as it was. It changes what's playing, so run it when nobody is listening. It takes a few minutes, as it waits for the speaker to power on and off.

## How it works

![A key press goes to KEF Remote, which sends the command to the speaker over TCP port 50001. An SSDP search on the local network finds the speaker, which replies with its IP.](docs/images/how-it-works.svg)

The app talks to the speaker over TCP on port 50001, the protocol the KEF Control app uses. Volume and mute live in one register, and power, input and standby are packed into the bits of another.

To find the speaker, it sends an SSDP search (the same one UPnP devices answer) and reads each reply's description to pick out the KEF. It saves the IP, and searches again if the speaker stops answering there.

The code is a Swift package with four targets:

- **KEFRemoteCore**: the protocol, speaker commands, TCP connection, discovery, config and logging, with no UI.
- **KEFRemote**: the macOS app, with volume key interception, the on-screen display, the menu bar, settings and the shortcuts.
- **kef-discover**: runs discovery once and prints each step (`make discover`).
- **kef-check**: runs every speaker command, reads each back and puts the speaker back as it was (`make speaker-check`).

## Credits

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus (MIT License), for the global shortcuts.
- [kefctl](https://github.com/kraih/kefctl), a Perl reference implementation (Artistic License 2.0), for the details of the KEF speaker protocol.

## Licence

MIT. See [LICENSE](LICENSE).
