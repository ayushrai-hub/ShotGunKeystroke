# Security Policy

ShotgunKeystroke holds the macOS **Input Monitoring** permission, which in principle allows observing every keystroke on the system. That makes it a keylogger-shaped app, so its security posture matters more than its size suggests.

## Supported Versions

Only the latest release and the current `main` branch receive fixes.

## Reporting a Vulnerability

Please **do not** open a public issue, PR, or discussion with vulnerability details.

GitHub private vulnerability reporting is not currently enabled on this repository. Until it is:

1. Open a public issue titled **"Security contact request"** with **no technical details**, or reach the maintainer through their GitHub profile ([@Piyushsomething](https://github.com/Piyushsomething)).
2. Share the details only once a private channel is established.

Include the affected version/commit, macOS version, reproduction steps, and impact. Please allow reasonable time for a fix before public disclosure.

## Security Model

What the app guarantees, and where each guarantee is enforced:

| Property | Enforcement |
|---|---|
| Never reads which key was pressed | `AppDelegate.handleTap` only reads the event type, the auto-repeat flag, and modifier flags — never key codes or characters. |
| Cannot modify, block, or inject input | The `CGEventTap` is created with `.listenOnly`. |
| No network access | No networking APIs are used anywhere in the code. |
| No data written except preferences | The only persistence is `UserDefaults` (on/off, volume, toggles, custom sound path). |
| Other local code can't borrow the permission | `build.sh` signs with the hardened runtime (`--options runtime`), which makes dyld ignore `DYLD_INSERT_LIBRARIES` and similar injection. |
| No third-party code | Apple system frameworks only; no package dependencies. |

## Known Limitations

- **Release binaries are ad-hoc signed and not notarized.** They can't be cryptographically tied to this source or to a known developer, and installing them requires bypassing Gatekeeper. Building from source avoids trusting the binary.
- **`scripts/setup-signing.sh` modifies your login keychain.** It imports a self-generated code-signing certificate and private key and marks the certificate trusted for code signing only. The certificate is a non-CA leaf (`CA:false`) and can't issue other certificates. The private key never leaves your machine; the temporary PEM/P12 files are deleted on exit. Remove it any time with Keychain Access (search "ShotgunKeystroke Dev Signing").
- **Custom sound files are decoded by AVFoundation.** Only files you pick in the open panel are loaded, but they are parsed by the system audio decoders.
- **Preferences are user-writable.** Any process running as your user can edit the app's `UserDefaults`, e.g. `customSoundPath`. The only effect is that the app tries to decode that path as audio, falling back to the built-in sound on failure.
- **Ad-hoc rebuilds reset the permission.** `build.sh` runs `tccutil reset ListenEvent dev.piyush.shotgunkeystroke` for ad-hoc builds. It is scoped to this bundle identifier only.

## Handling Secrets

The project uses no API keys, tokens, or credentials. Never commit signing material (`.p12`, `.pfx`, `.pem`, `.key`, `.cer`, provisioning profiles) or `.env` files; `.gitignore` excludes them. If a signing key is ever committed, treat it as compromised: delete it from the keychain, generate a new one, and note that removing it in a later commit does not remove it from Git history.
