# Contributing

Thanks for wanting to make ShotgunKeystroke louder, smaller, or more reliable.

## Code of Conduct

Be respectful and constructive. Critique code, not people. Assume good intent, keep discussions on topic, and be patient with newcomers. Maintainers may close or moderate threads that don't meet this standard.

## Before You Start

- Read [README.md](README.md), especially [Architecture](README.md#architecture) and [Security & Privacy](README.md#security--privacy).
- Check [open issues](https://github.com/Piyushsomething/ShotGunKeystroke/issues) to avoid duplicate work. For anything bigger than a small fix, open an issue first to agree on the approach.
- Understand the privacy promise: **the app must never read which key was pressed.** Contributions that read key codes or characters, log input, add network access, or weaken the listen-only event tap will not be accepted.

## Development Setup

Requirements: macOS 13+, Swift 5.9+ (Xcode or Command Line Tools), Python 3 (only for sound regeneration). Optional: `shellcheck`, `swiftlint`.

```bash
git clone https://github.com/Piyushsomething/ShotGunKeystroke.git
cd ShotGunKeystroke
bash scripts/check.sh            # build + tests + lint gates
./build.sh && open build/ShotgunKeystroke.app
```

Grant Input Monitoring on first launch. Running `bash scripts/setup-signing.sh` once gives every rebuild a stable signature so you don't have to re-grant after each build (it adds a self-signed code-signing certificate to your login keychain — read the script first).

## Branching Strategy

- `main` — stable; always builds and passes `scripts/check.sh`.
- Work on a short-lived branch off `main`:
  - `feature/<short-description>` — new behavior
  - `fix/<short-description>` — bug fixes
  - `docs/<short-description>` — documentation only
  - `refactor/<short-description>` — no behavior change
  - `chore/<short-description>` — build, tooling, repo maintenance

Rebase on or merge the latest `main` before opening a PR. Never force-push to `main`.

## Making Changes

- **Small and focused.** One logical change per PR. Separate refactors from behavior changes.
- **No new dependencies** without prior discussion — "no dependencies" is a feature.
- **Backward compatibility.** Don't rename or repurpose existing `UserDefaults` keys (`isArmed`, `volume`, `fireOnRepeat`, `fireOnModifiers`, `customSoundPath`) or the bundle identifier; existing users would lose settings or their permission grant.
- **Tests.** Add or update tests in `Tests/ShotgunKeystrokeTests/` for logic that can run headless (settings, audio loading, pure helpers). Tests must stay silent — don't call `SoundEngine.fire()`.
- **Documentation.** Update README.md when you change features, menu items, build steps, or requirements.
- **Security.** Keep the event tap `.listenOnly`; keep hardened-runtime signing in `build.sh`; never commit signing material or credentials.
- **Error handling.** Fail safe and visibly: keep the current sound when a new one can't load, show an `NSAlert` for user-initiated failures, and `NSLog` with the `ShotgunKeystroke:` prefix for background issues. Don't crash on missing files or permissions.

## Testing Requirements

Before opening a PR, run:

```bash
bash scripts/check.sh
```

It must pass. It runs a strict release build (warnings are errors), the unit tests, `shellcheck`, and the `shotgun.wav` reproducibility check. If you intentionally change the sound, commit the regenerated `Resources/shotgun.wav` together with the `generate_sound.py` change.

### Manual test checklist

The event tap and menu need a real session and permission, so also verify by hand when you touch `AppDelegate.swift`, `SoundEngine.swift`, `build.sh`, or `Info.plist`:

1. `./build.sh && open build/ShotgunKeystroke.app`; grant Input Monitoring if prompted.
2. Typing letters fires; ceasefire silences it; re-arming fires one shot.
3. Volume slider changes loudness and previews on release.
4. Fire on Key Repeat and Fire on Modifier Keys toggles behave as labeled.
5. Choose Sound File… accepts an audio file and rejects a non-audio one with an alert; Reset restores the shotgun.
6. Launch at Login toggles without an error (from the `.app`, not `swift run`).
7. `codesign -dv build/ShotgunKeystroke.app` shows `flags=0x10002(adhoc,runtime)` (or `runtime` with your identity).

## Code Quality

- No enforced formatter or linter config. Follow the existing style: 4-space indentation, `// MARK: -` sections, `private` by default, doc comments on non-obvious behavior (especially anything permission- or privacy-related).
- The build must be warning-free (`scripts/check.sh` enforces `-warnings-as-errors`).
- Shell scripts must pass `shellcheck` and use `set -euo pipefail`.
- `swiftlint lint Sources` is available for optional style hints (see README for the Command Line Tools workaround); don't reformat unrelated code to satisfy it.

## Commit Messages

This repository uses short, imperative, sentence-style subjects (no type prefixes), e.g.:

```
Add custom sound picker to the menu (v1.1.0)
Fix stranded Input Monitoring grants after rebuilds (v1.1.1)
Replace NSEvent global monitor with listen-only CGEventTap
```

- Subject: imperative mood, capitalized, no trailing period, ~72 characters max.
- Body (optional, wrapped at ~72): explain *why* and any user-visible impact.
- Mention the version in the subject when a commit bumps `CFBundleShortVersionString`.

## Pull Requests

Every PR description should include:

- **What** changed and **why** (link the issue if there is one).
- **Testing performed** — `scripts/check.sh` output plus which manual checklist items you ran.
- **Screenshots** of the menu for any UI change.
- **Migration notes** if settings keys, bundle id, signing, or permissions are affected.
- **Breaking changes** called out explicitly.

## Security Issues

Please **do not** open a public issue for security vulnerabilities. Follow [SECURITY.md](SECURITY.md).
