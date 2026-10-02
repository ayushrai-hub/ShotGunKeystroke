# 🔫 ShotgunKeystroke

**Every keystroke on your Mac fires a shotgun.** That's it. That's the app.

A free, open-source **keyboard sound effects app for macOS** — typing sounds for your Mac, but instead of mechanical keyboard clicks you get a 12-gauge. Think Klack, Tickeys, or Mechvibes, with more caliber.

Tiny native menu bar app written in Swift — no Electron, no dependencies, under 1 MB, near-zero CPU when idle, and it never reads what you type.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License: MIT](https://img.shields.io/badge/License-MIT-green) ![Size](https://img.shields.io/badge/App%20Size-~1MB-lightgrey)

## Overview

ShotgunKeystroke lives in the menu bar (no Dock icon) and plays a sound every time a key goes down anywhere on the system. It is a novelty / fun app: the whole point is the sound, with just enough controls (volume, on/off, custom sound) to make it livable.

## Problem

Keyboard-sound apps exist, but they mostly imitate mechanical switches. This one exists to make typing absurdly dramatic — while staying small, native, and privacy-respecting, since any app that hears global keystrokes is in a position of trust.

## Features

- **🔫 / 🕊️ On/Off switch** — one click declares war, one click calls a ceasefire. The menu bar icon swaps emoji *and* dims so you always know whether the guns are up.
- **Volume 10–100%** — from "polite office skirmish" to "the neighbors are calling someone". You pick the caliber. Releasing the slider fires a preview shot at the new level.
- **Hold-to-repeat? Optional.** — holding backspace shouldn't sound like a machine gun. Unless — hear us out — you want it to. Off by default.
- **Modifier keys too** — optionally let ⇧ ⌘ ⌥ ⌃ join the fight. ⌘S has never felt this dramatic. Off by default.
- **Launch at login** — for a permanent state of war. Your Mac boots, the shotgun racks. All settings persist across restarts.
- **🎯 Test Fire** — preview the blast without typing a single character. It's called range practice. Look it up.
- **Custom sounds** — "Choose Sound File…" in the menu swaps the shotgun for any WAV/MP3/M4A/AIFF you like. Ducks, dial-up, your own voice — we don't judge. One click resets to the shotgun.

## Architecture

A single-process AppKit menu bar app (`LSUIElement`, accessory activation policy). Four source files:

| Component | File | Responsibility |
|---|---|---|
| Entry point | `main.swift` | Creates `NSApplication`, installs `AppDelegate`, hides the Dock icon. |
| Menu + key listener | `AppDelegate.swift` | Builds the status-bar menu, manages the Input Monitoring permission, and owns the keyboard event tap. |
| Audio | `SoundEngine.swift` | Pool of 8 preloaded `AVAudioPlayer`s played round-robin so fast typing overlaps shots instead of cutting them off. |
| Preferences | `Settings.swift` | Typed wrapper over `UserDefaults` (armed, volume, repeat, modifiers, custom sound path). |

### How it works

1. On launch the app checks the **Input Monitoring** permission (`IOHIDCheckAccess`) and requests it if missing.
2. Once granted, it installs a **listen-only** `CGEventTap` at the session level for `keyDown` and `flagsChanged` events. Listen-only means it can observe events but cannot modify, block, or inject them.
3. For each event it looks at only three things: *that* a key went down, the auto-repeat flag, and which modifier class changed. It never reads key codes or characters.
4. If permission is missing (or revoked), the tap is torn down and the app re-checks every 2 seconds, so shots start the moment access is granted — no relaunch needed.
5. Each shot calls `SoundEngine.fire()`, which rewinds and plays the next player in the pool.

The built-in sound is synthesized from scratch by [`scripts/generate_sound.py`](scripts/generate_sound.py) (noise crack + low-passed boom + sub-bass thump) with a seeded RNG, so the committed `Resources/shotgun.wav` is byte-for-byte reproducible and has no licensing concerns.

## Tech Stack

- **Swift** (tools version 5.9), built with **Swift Package Manager** — no Xcode project
- **AppKit** (menu bar UI), **CoreGraphics** event taps + **IOKit HID** (permission checks), **AVFoundation** (playback), **ServiceManagement** (launch at login), **UniformTypeIdentifiers** (sound picker)
- **swift-testing** for unit tests
- **Python 3** (stdlib only) for the sound generator
- **Bash** build/signing scripts

No third-party dependencies, so there is no `Package.resolved` lockfile.

## Requirements

- macOS 13 Ventura or later (to run and build)
- Swift 5.9+ toolchain — either Xcode or just the Command Line Tools (`xcode-select --install`)
- Python 3 — only if you want to regenerate the built-in sound
- Optional: [`shellcheck`](https://www.shellcheck.net) for linting the shell scripts, [`swiftlint`](https://github.com/realm/SwiftLint) for Swift style hints

Last verified with Apple Swift 6.3.3 (Command Line Tools) on macOS 26.5.

## Installation

### Option 1: Download a release

Grab `ShotgunKeystroke.app.zip` from the [Releases page](https://github.com/Piyushsomething/ShotGunKeystroke/releases), unzip, and drag `ShotgunKeystroke.app` into `/Applications`.

Because the app is ad-hoc signed (not notarized), macOS Gatekeeper will block the first launch. Right-click the app → **Open** → **Open**, or clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/ShotgunKeystroke.app
```

Release binaries aren't notarized and can't be verified against this source. If that matters to you, build from source instead (Option 2).

### Option 2: Build from source

```bash
git clone https://github.com/Piyushsomething/ShotGunKeystroke.git
cd ShotGunKeystroke
./build.sh
open build/ShotgunKeystroke.app
```

### First launch: grant Input Monitoring access

macOS requires the **Input Monitoring** permission before any app can observe global keystrokes (Accessibility is *not* enough — without Input Monitoring, macOS only delivers modifier-key events, so you'd hear shots on ⌘⌥⌃ but silence while typing). On first launch you'll get a prompt — or open **System Settings → Privacy & Security → Input Monitoring** and enable **ShotgunKeystroke**. The menu shows a ⚠️ item that takes you straight there until access is granted.

> **Rebuilding from source?** Ad-hoc signatures change on every build, which strands the previous permission grant — the telltale symptom is modifier keys (⌘⌥⌃) firing while letter keys stay silent. `build.sh` handles this automatically: it clears the stale grant (`tccutil reset`), so the next launch shows a fresh one-click prompt. To avoid re-granting entirely, run `bash scripts/setup-signing.sh` once — it creates a self-signed certificate that `build.sh` auto-detects, giving every build the same stable signature. (Or use your own identity: `CODESIGN_IDENTITY="Apple Development: you@… (TEAMID)" ./build.sh`)

## Environment Variables

The app itself reads no environment variables and needs no secrets, so there is no `.env` file or `.env.example`.

The build script accepts one optional variable:

| Variable | Used by | Purpose |
|---|---|---|
| `CODESIGN_IDENTITY` | `build.sh` | Code-signing identity name. If unset, `build.sh` uses the `ShotgunKeystroke Dev Signing` certificate when present, otherwise ad-hoc signing (`-`). |

## Local Development

```bash
swift build          # debug build
swift run            # run unbundled (custom sounds work; Launch at Login does not)
./build.sh           # release build → build/ShotgunKeystroke.app (signed, hardened runtime)
open build/ShotgunKeystroke.app
```

`swift run` resolves the built-in sound from `Resources/shotgun.wav` relative to the current directory, so run it from the repo root. Input Monitoring is granted to whichever binary asks — the terminal-launched binary and the `.app` bundle are separate entries in System Settings.

## Testing

Run every quality gate with one command:

```bash
bash scripts/check.sh
```

It runs, in order:

1. a strict release build (`-warnings-as-errors`)
2. the unit tests (`swift test`)
3. `shellcheck` on all shell scripts (skipped with a notice if not installed)
4. a reproducibility check that regenerating the sound yields an identical `Resources/shotgun.wav`

With Xcode installed you can also run the tests directly with `swift test`. With only the Command Line Tools, plain `swift test` fails with `no such module 'Testing'` because SwiftPM doesn't add the bundled framework's path — `scripts/check.sh` adds the required flags automatically.

The tests cover `Settings` (defaults, volume clamping, persistence) and `SoundEngine` (loading the built-in sound, rejecting missing and non-audio files). They never call `fire()`, so running them is silent. The event tap and menu UI need a real login session and the Input Monitoring permission, so they are verified manually (see [CONTRIBUTING.md](CONTRIBUTING.md#manual-test-checklist)).

## Linting / Formatting

There is no enforced formatter or linter config. Match the style of the surrounding code (4-space indentation, `// MARK:` sections, doc comments on non-obvious behavior).

Optional style hints:

```bash
swiftlint lint Sources
```

With only the Command Line Tools, SwiftLint crashes loading `sourcekitdInProc`; point it at the CLT toolchain:

```bash
TOOLCHAIN_DIR=/Library/Developer/CommandLineTools swiftlint lint Sources
```

With SwiftLint's default rules the current code reports a few style warnings (long function/class bodies, trailing commas) and no errors. These are informational, not a gate.

## Build

```bash
./build.sh
```

This builds in release mode, assembles `build/ShotgunKeystroke.app` (binary + `Info.plist` + `shotgun.wav`), and signs it with the hardened runtime. When signing ad-hoc it also resets the stale Input Monitoring grant for `dev.piyush.shotgunkeystroke`.

To change the built-in sound, edit `scripts/generate_sound.py` and run:

```bash
python3 scripts/generate_sound.py && ./build.sh
```

## Deployment

Releases are published manually as `ShotgunKeystroke.app.zip` assets on [GitHub Releases](https://github.com/Piyushsomething/ShotGunKeystroke/releases) (tags `v1.0.0`, `v1.1.1`). There is no CI or scripted release pipeline in this repository. Releases are ad-hoc signed and not notarized.

The landing page in [`docs/index.html`](docs/index.html) is served by GitHub Pages at [piyushsomething.github.io/ShotGunKeystroke](https://piyushsomething.github.io/ShotGunKeystroke/).

## Project Structure

```
Package.swift                    Swift Package Manager manifest (app + test targets)
Info.plist                       App bundle metadata (bundle id, LSUIElement=true)
Sources/ShotgunKeystroke/
  main.swift                     Entry point
  AppDelegate.swift              Menu bar UI, permission handling, event tap
  SoundEngine.swift              AVAudioPlayer pool
  Settings.swift                 Persisted preferences (UserDefaults)
Tests/ShotgunKeystrokeTests/     swift-testing unit tests
Resources/shotgun.wav            The blast (generated, committed)
scripts/
  generate_sound.py              Sound synthesizer (stdlib Python)
  setup-signing.sh               One-time stable self-signed signing identity
  check.sh                       All quality gates in one command
build.sh                         Builds + signs build/ShotgunKeystroke.app
docs/index.html                  GitHub Pages landing page
```

## Usage

Click the 🔫 in the menu bar:

| Menu item | What it does |
|---|---|
| 🕊️ Ceasefire / 🔫 Declare War | Master on/off. Arming fires one shot so you know it's live. |
| 🎯 Test Fire | Plays the current sound once. |
| Volume slider | 10–100%; releasing the slider plays a preview. |
| Choose Sound File… | Pick any decodable audio file. Undecodable files are rejected and the current sound is kept. |
| Reset to Shotgun Blast | Shown only when a custom sound is active. |
| Fire on Key Repeat | Fire on auto-repeat while a key is held. Off by default. |
| Fire on Modifier Keys | Fire on ⇧ ⌘ ⌥ ⌃ / Caps Lock presses. Off by default. |
| Launch at Login | Registers the app bundle via `SMAppService`. |
| ⚠️ Grant Input Monitoring Access… | Shown only while permission is missing; opens System Settings. |

Settings are stored in the app's `UserDefaults` domain (`dev.piyush.shotgunkeystroke`).

## Troubleshooting

- **Modifier keys fire but letters are silent** — the Input Monitoring grant belongs to an older signature. Rebuild with `./build.sh` (it resets the grant) and approve the new prompt, or remove and re-add ShotgunKeystroke under Input Monitoring.
- **No sound at all** — check the menu for the ⚠️ permission item, make sure the app is armed (🔫, not 🕊️), and use 🎯 Test Fire to rule out volume/output-device issues.
- **"Couldn't change Launch at Login"** — only works from the `.app` bundle, not `swift run`.
- **macOS says the app can't be opened** — Gatekeeper quarantine on a downloaded release; see [Installation](#option-1-download-a-release).
- **`no such module 'Testing'`** — you're on the Command Line Tools; use `bash scripts/check.sh`.
- **SwiftLint fatal error loading `sourcekitdInProc`** — prefix with `TOOLCHAIN_DIR=/Library/Developer/CommandLineTools`.

## Security & Privacy

This app never reads *which* key you pressed. It reacts to the fact that *a* key went down — no key codes, no characters, no logging, no network access, no file writes beyond its own preferences. The event tap is listen-only, and the bundle is signed with the hardened runtime so other local code can't inject itself and inherit the Input Monitoring permission.

There are no secrets in this project. Never commit signing material (`.p12`, `.pem`, keys, provisioning profiles); `.gitignore` excludes them.

See [SECURITY.md](SECURITY.md) for the threat model and how to report a vulnerability.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). Fire at will.
