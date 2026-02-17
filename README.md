# kef-remote

A TypeScript library and CLI for controlling KEF wireless speakers
(LS50 Wireless and LSX) over the local network.

Communicates via a reverse-engineered TCP protocol on port 50001,
based on the KEF Control mobile app (firmware 4.1).

Based on [kefctl](https://github.com/kraih/kefctl) by Sebastian Riedel,
a Perl implementation that served as the protocol reference for this
TypeScript rewrite.

## Features

- Power on/off with smart auto-wake
- Volume control (set, raise, lower)
- Mute/unmute
- Input source switching (wifi, USB, Bluetooth, aux, optical)
- Speaker status reporting
- Automatic speaker discovery (no hardcoded IPs)
- Interactive hardware verification

The underlying library also supports playback control, DSP settings,
and standby configuration.

## Tech Stack

- **TypeScript** on **Bun** runtime
- Bun native TCP API for speaker communication
- `bun test` for testing

## Context

This is a personal project born from wanting to control my KEF speakers
from my Mac without relying on the mobile app. It also serves as a
learning project for exploring systems-level programming in TypeScript
(TCP protocols, byte manipulation, network discovery) and for developing
agentic AI development workflows using Claude Code CLI.

## Status

Work in progress.
