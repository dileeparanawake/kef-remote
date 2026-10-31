# KEF Remote: privacy policy

Version 1.1.0 · covers KEF Remote 0.4.0 · last updated 31 October 2026

**In short**

- No tracking. No analytics, no account, no servers.
- It only talks to devices on your own network, never to the internet.
- What it keeps stays on your Mac.
- I only get something if you choose to email me.

## Who is responsible

KEF Remote is made by Dileepa Ranawake, a sole trader in Hull, UK. I'm the data controller for anything you choose to send me.

Contact: dileeparanawake@gmail.com

## What it's for

One purpose: control your KEF speaker from your Mac: power, volume, mute and input.

## What it talks to, and why

Only devices on your own network.

- To find your speaker, it sends a search on your local network and reads the short description each media device gives back, to pick out the KEF. It only reads descriptions from addresses on your own network and won't follow a redirect, so a device can't send it on to the internet.
- Then it sends commands to the speaker.

The app itself never connects to the internet. Three links open a page in your web browser: Made by Dileepa (my website), Buy me a coffee… (my Ko-fi page) and Privacy (this page, on GitHub). Those sites have their own privacy policies.

## What it keeps on your Mac

A few things, so it can find the speaker again and remember your choices:

- `~/.kef-remote/config.json`: your speaker's name, model, IP address and serial number, and your settings, including your home Wi-Fi name if you set one.
- `~/.kef-remote/logs/kef-remote.log`: what the app did, such as the commands it sent to the speaker. It also holds your speaker's name, IP address and serial number, the addresses of other devices on your network that answered the search, your home Wi-Fi name if you set one, and the name of the Wi-Fi you're on when macOS shares it. A new log starts each time the app opens.
- `~/.kef-remote/logs/kef-remote.previous.log`: the log from the time before, kept so a freeze or a restart doesn't wipe it. Same kinds of data. Each time the app opens, it replaces this file with the last log.
- Your shortcuts and modifier key, in `~/Library/Preferences/com.dileeparanawake.KEFRemote.plist`.

The logs write your home folder as `~`, so your Mac's account name stays out of them.

Each log line also goes to the macOS system log. macOS keeps only the warnings and errors there, and clears them on its own. If the app crashes, macOS may offer to send a report to Apple. I don't receive it.

**How long:** until you remove them. To remove it all, delete the app, the `~/.kef-remote` folder and the preferences file above.

## What it never does

- No analytics, tracking, ads or crash reporting of its own.
- No account and no servers.
- It doesn't see what you type: it only listens for the volume and mute keys.
- Nothing leaves your Mac unless you send it to me yourself.

## If you send me feedback

Send feedback… in the menu opens an email to me in your own email app. It fills in the app version, your macOS version, and your speaker's name and model. It asks first whether to attach the log. You see everything before you send it, and nothing is sent unless you send it.

If you do, I get your email, including your email address, your name as your email app sends it, and anything you attached.

**Why:** to reply and to improve the app. That is my legitimate interest: you wrote to me, and I need your email to reply.

**Where it's kept:** my Gmail inbox. For that, Google is a controller in its own right, under [Google's privacy policy](https://policies.google.com/privacy). Google is a US company and may store it in the US; it is certified to the UK–US data bridge. Only I read it. It is never sold, shared or added to a mailing list.

**How long:** I delete feedback emails 2 years after our last message, or sooner if you ask.

## If you buy me a coffee

Buy me a coffee… opens my Ko-fi page in your browser. If you pay, Ko-fi and its payment provider handle the payment under [Ko-fi's privacy policy](https://more.ko-fi.com/privacy), and Ko-fi tells me about it.

**Why I keep it:** UK tax law asks me to keep records of what I'm paid. **How long:** 5 years after the 31 January deadline for that year's tax return.

## Downloading

KEF Remote is downloaded from GitHub, which has [its own privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).

## Permissions

- **Local Network:** to find your speaker and send it commands.
- **Accessibility:** to catch the volume and mute keys.

## Your rights

Under UK data protection law you can ask me for a copy of anything I hold about you, and ask me to correct it, delete it, limit how I use it, or stop using it. Email dileeparanawake@gmail.com; I'll reply within one month.

**You can object** to my using your feedback at any time: email me and I'll stop.

What's on your Mac is yours: deleting the files above removes it.

If you're unhappy with how I've handled your data, you can complain to the [Information Commissioner's Office (ICO)](https://ico.org.uk/make-a-complaint/).

## Changes

If what the app does with data ever changes, this page changes first, and the version and date above go up.
