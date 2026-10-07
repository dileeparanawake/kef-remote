# Privacy

Last updated: 6 October 2026

KEF Remote collects nothing about you. It has no analytics, no tracking and no account, and it doesn't send anything to me or to anyone else.

## What stays on your Mac

KEF Remote only talks to devices on your own network. To find your speaker, it sends a search on your local network and reads the description each media device gives back, to pick out the KEF. Then it sends commands to the speaker. The app itself never connects to the internet. Made by Dileepa in the menu opens my website in your browser, and the Privacy link opens this notice on GitHub.

It asks for Accessibility only to catch the volume and mute keys. It doesn't see what you type.

It keeps a few things on your Mac so it can find the speaker again and remember your choices:

- `~/.kef-remote/config.json`: your speaker's name, model, IP address and serial number, and your settings, including your home Wi-Fi name if you set one.
- `~/.kef-remote/logs/kef-remote.log`: what the app did, such as the commands it sent to the speaker. It also holds your speaker's name, IP address and serial number, and the addresses of other devices on your network that answered the search. The log starts again each time the app opens.
- `~/.kef-remote/logs/kef-remote.previous.log`: the log from the time before, kept so a freeze or a restart doesn't wipe it. It holds the same kinds of data, and each time the app opens it replaces this file with the last log.
- Your shortcuts and modifier key, in `~/Library/Preferences/com.dileeparanawake.KEFRemote.plist`.

Each log line also goes to the macOS system log. macOS keeps only the warnings and errors there, and clears them on its own. If the app crashes, macOS may offer to send a report to Apple. I don't receive it.

None of this leaves your Mac unless you send it to me yourself (see below). To remove it all, delete the app, the `~/.kef-remote` folder and the preferences file above.

## If you send me feedback

To send feedback, choose Send feedback… in the menu. It opens an email to me in your own email app, with the app version, your macOS version, and your speaker's name and model filled in. It asks first whether to attach the log. You see everything before you send it, and nothing is sent unless you send it.

If you do, I get your email, including your email address and anything you attached. I use it only to reply and to improve the app. My lawful basis is legitimate interests: you wrote to me, and I need your email to reply.

My email is with Gmail, so Google stores your email for me. Google may keep it on servers outside the UK, under its safeguards for sending data abroad.

I delete feedback emails 2 years after our last message, or sooner if you ask.

## Downloading

KEF Remote is downloaded from GitHub, which has [its own privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).

## Your rights

I'm Dileepa Ranawake, and I'm responsible for any personal data you send me. Under UK data protection law you can ask me what I hold about you, and ask me to correct it, delete it, limit how I use it, or stop using it. Email me at dileeparanawake@gmail.com.

If you're not happy with how I've handled your data, you can complain to the [Information Commissioner's Office](https://ico.org.uk/make-a-complaint/).
