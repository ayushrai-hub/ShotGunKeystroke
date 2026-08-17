# 🔫 ShotgunKeystroke

Every keystroke on your Mac fires a shotgun. That's it. That's the app.

A tiny native macOS menu bar app written in Swift — no Electron, no
dependencies, ~1 MB, near-zero CPU when idle.

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

## First launch: grant Accessibility access

macOS requires permission before any app can observe global keystrokes.
On first launch you'll get a prompt — or open **System Settings →
Privacy & Security → Accessibility** and enable **ShotgunKeystroke**.
The menu shows a ⚠️ item that takes you straight there until access is
granted. Relaunch the app after granting.

> Rebuilding from source re-signs the binary, so macOS treats it as a
> new app — you may need to re-grant Accessibility after a rebuild
> (remove the old entry with the − button first).

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

Want a different sound entirely? Replace `Resources/shotgun.wav` with
any WAV file and rebuild.

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
