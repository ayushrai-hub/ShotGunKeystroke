# 🔫 ShotgunKeystroke

**Every keystroke on your Mac fires a shotgun.** That's it. That's the app.

A free, open-source **keyboard sound effects app for macOS** — typing
sounds for your Mac, but instead of mechanical keyboard clicks you get
a 12-gauge. Think Klack, Tickeys, or Mechvibes, with more caliber.

Tiny native menu bar app written in Swift — no Electron, no
dependencies, ~1 MB, near-zero CPU when idle, and it never reads what
you type.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License: MIT](https://img.shields.io/badge/License-MIT-green) ![Size](https://img.shields.io/badge/App%20Size-~1MB-lightgrey)

## Features

- **🔫 / 🕊️ On/Off switch** — one click declares war, one click calls a
  ceasefire. The menu bar icon swaps emoji *and* dims so you always know
  whether the guns are up.
- **Volume 10–100%** — from "polite office skirmish" to "the neighbors
  are calling someone". You pick the caliber. Releasing the slider
  fires a preview shot at the new level.
- **Hold-to-repeat? Optional.** — holding backspace shouldn't sound like
  a machine gun. Unless — hear us out — you want it to. Off by default.
- **Modifier keys too** — optionally let ⇧ ⌘ ⌥ ⌃ join the fight.
  ⌘S has never felt this dramatic. Off by default.
- **Launch at login** — for a permanent state of war. Your Mac boots,
  the shotgun racks. All settings persist across restarts.
- **🎯 Test Fire** — preview the blast without typing a single
  character. It's called range practice. Look it up.
- **Custom sounds** — "Choose Sound File…" in the menu swaps the
  shotgun for any WAV/MP3/M4A/AIFF you like. Ducks, dial-up, your own
  voice — we don't judge. One click resets to the shotgun.

## Install

### Option 1: Download a release

Grab `ShotgunKeystroke.app.zip` from the
[Releases](../../releases) page, unzip, and drag
`ShotgunKeystroke.app` into `/Applications`.

Because the app is ad-hoc signed (not notarized), macOS Gatekeeper will
block the first launch. Right-click the app → **Open** → **Open**, or
clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/ShotgunKeystroke.app
```

### Option 2: Build from source

Requires macOS 13+ and the Swift toolchain (Xcode or Command Line Tools).

```bash
git clone https://github.com/<you>/ShotGunKeystroke.git
cd ShotGunKeystroke
./build.sh
open build/ShotgunKeystroke.app
```

## First launch: grant Input Monitoring access

macOS requires the **Input Monitoring** permission before any app can
observe global keystrokes (Accessibility is *not* enough — without
Input Monitoring, macOS only delivers modifier-key events, so you'd
hear shots on ⌘⌥⌃ but silence while typing). On first launch you'll
get a prompt — or open **System Settings → Privacy & Security → Input
Monitoring** and enable **ShotgunKeystroke**. The menu shows a ⚠️ item
that takes you straight there until access is granted. Relaunch the
app after granting.

> **Rebuilding from source?** Ad-hoc signatures change on every build,
> which strands the previous permission grant — the telltale symptom is
> modifier keys (⌘⌥⌃) firing while letter keys stay silent. `build.sh`
> handles this automatically: it clears the stale grant (`tccutil
> reset`), so the next launch shows a fresh one-click prompt. To avoid
> re-granting entirely, run `bash scripts/setup-signing.sh` once — it
> creates a self-signed certificate that `build.sh` auto-detects, giving
> every build the same stable signature. (Or use your own identity:
> `CODESIGN_IDENTITY="Apple Development: you@… (TEAMID)" ./build.sh`)

## Privacy

This app never reads *which* key you pressed. It listens for key-down
events and reacts to the fact that *a* key went down — no key codes, no
characters, no logging, no network access. Read
[`AppDelegate.swift`](Sources/ShotgunKeystroke/AppDelegate.swift) — it's
one file.

## How it works

- `NSEvent.addGlobalMonitorForEvents` observes key-down events
  system-wide (this is what needs Accessibility permission).
- A pool of 8 preloaded `AVAudioPlayer`s plays the blast round-robin, so
  fast typing overlaps shots instead of cutting them off.
- The shotgun sound itself is synthesized from scratch by
  [`scripts/generate_sound.py`](scripts/generate_sound.py)
  (noise crack + low-passed boom + sub-bass thump) — no licensing
  worries, and you can tweak the recipe and regenerate:

```bash
python3 scripts/generate_sound.py && ./build.sh
```

Want a different sound entirely? Use **Choose Sound File…** in the
menu (no rebuild needed), or replace `Resources/shotgun.wav` and
rebuild to change the built-in default.

## Project layout

```
Package.swift                  Swift Package Manager manifest
Sources/ShotgunKeystroke/
  main.swift                   entry point
  AppDelegate.swift            menu bar UI + global key monitor
  SoundEngine.swift            AVAudioPlayer pool
  Settings.swift               persisted preferences (UserDefaults)
Resources/shotgun.wav          the blast (generated, committed)
scripts/generate_sound.py      sound synthesizer
Info.plist                     app bundle metadata (LSUIElement=true)
build.sh                       builds + assembles ShotgunKeystroke.app
```

## License

[MIT](LICENSE). Fire at will.
