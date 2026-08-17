import AppKit
import IOKit.hid
import ServiceManagement
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var engine: SoundEngine!
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapRetryTimer: Timer?
    private var lastModifierFlags: CGEventFlags = []

    private var toggleItem: NSMenuItem!
    private var volumeLabelItem: NSMenuItem!
    private var volumeSlider: NSSlider!
    private var chooseSoundItem: NSMenuItem!
    private var resetSoundItem: NSMenuItem!
    private var repeatItem: NSMenuItem!
    private var modifiersItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var permissionItem: NSMenuItem!

    private static let trackedModifiers: CGEventFlags = [
        .maskShift, .maskControl, .maskAlternate, .maskCommand, .maskAlphaShift,
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine = SoundEngine(volume: Settings.volume)
        setupStatusItem()
        requestInputMonitoringIfNeeded()
        startEventTap()
        refreshUI()
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()

        toggleItem = NSMenuItem(
            title: "Ceasefire",
            action: #selector(toggleArmed),
            keyEquivalent: "t"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let testItem = NSMenuItem(
            title: "🎯 Test Fire",
            action: #selector(testFire),
            keyEquivalent: " "
        )
        testItem.target = self
        menu.addItem(testItem)

        menu.addItem(.separator())

        volumeLabelItem = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
        volumeLabelItem.isEnabled = false
        menu.addItem(volumeLabelItem)

        let sliderContainer = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 28))
        volumeSlider = NSSlider(
            value: Double(Settings.volume * 100),
            minValue: 10,
            maxValue: 100,
            target: self,
            action: #selector(volumeChanged(_:))
        )
        volumeSlider.frame = NSRect(x: 22, y: 2, width: 176, height: 24)
        volumeSlider.isContinuous = true
        sliderContainer.addSubview(volumeSlider)
        let sliderItem = NSMenuItem()
        sliderItem.view = sliderContainer
        menu.addItem(sliderItem)

        menu.addItem(.separator())

        chooseSoundItem = NSMenuItem(
            title: "Choose Sound File…",
            action: #selector(chooseSound),
            keyEquivalent: ""
        )
        chooseSoundItem.target = self
        menu.addItem(chooseSoundItem)

        resetSoundItem = NSMenuItem(
            title: "Reset to Shotgun Blast",
            action: #selector(resetSound),
            keyEquivalent: ""
        )
        resetSoundItem.target = self
        menu.addItem(resetSoundItem)

        menu.addItem(.separator())

        repeatItem = NSMenuItem(
            title: "Fire on Key Repeat",
            action: #selector(toggleRepeat),
            keyEquivalent: ""
        )
        repeatItem.target = self
        menu.addItem(repeatItem)

        modifiersItem = NSMenuItem(
            title: "Fire on Modifier Keys (⇧⌘⌥⌃)",
            action: #selector(toggleModifiers),
            keyEquivalent: ""
        )
        modifiersItem.target = self
        menu.addItem(modifiersItem)

        loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())

        permissionItem = NSMenuItem(
            title: "⚠️ Grant Input Monitoring Access…",
            action: #selector(openInputMonitoringSettings),
            keyEquivalent: ""
        )
        permissionItem.target = self
        menu.addItem(permissionItem)

        let quitItem = NSMenuItem(
            title: "Quit ShotgunKeystroke",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu
    }

    private func refreshUI() {
        let armed = Settings.isArmed
        statusItem.button?.title = armed ? "🔫" : "🕊️"
        statusItem.button?.appearsDisabled = !armed
        statusItem.button?.toolTip = armed
            ? "ShotgunKeystroke — armed"
            : "ShotgunKeystroke — ceasefire"

        toggleItem.title = armed ? "🕊️ Ceasefire" : "🔫 Declare War"
        toggleItem.state = armed ? .on : .off

        volumeLabelItem.title = "Volume: \(Int((Settings.volume * 100).rounded()))%"
        volumeSlider.doubleValue = Double(Settings.volume * 100)

        if let path = Settings.customSoundPath {
            resetSoundItem.isHidden = false
            resetSoundItem.title =
                "Reset to Shotgun Blast (now: \(URL(fileURLWithPath: path).lastPathComponent))"
        } else {
            resetSoundItem.isHidden = true
        }

        repeatItem.state = Settings.fireOnRepeat ? .on : .off
        modifiersItem.state = Settings.fireOnModifiers ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

        permissionItem.isHidden = hasInputMonitoringAccess
    }

    // MARK: - Actions

    @objc private func toggleArmed() {
        Settings.isArmed.toggle()
        if Settings.isArmed {
            engine.fire()  // rack the shotgun so you know it's live
        }
        refreshUI()
    }

    @objc private func testFire() {
        engine.fire()
    }

    @objc private func volumeChanged(_ sender: NSSlider) {
        Settings.volume = Float(sender.doubleValue / 100)
        engine.volume = Settings.volume
        volumeLabelItem.title = "Volume: \(Int(sender.doubleValue.rounded()))%"
        // Preview the new level once the user releases the slider.
        if NSApp.currentEvent?.type == .leftMouseUp {
            engine.fire()
        }
    }

    @objc private func chooseSound() {
        let panel = NSOpenPanel()
        panel.message = "Pick any audio file (WAV, MP3, M4A, AIFF…) to fire on each keystroke"
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if engine.load(url: url) {
            Settings.customSoundPath = url.path
            engine.fire()
        } else {
            let alert = NSAlert()
            alert.messageText = "Couldn't load that file"
            alert.informativeText = "It doesn't seem to be a decodable audio file. The current sound is unchanged."
            alert.runModal()
        }
        refreshUI()
    }

    @objc private func resetSound() {
        Settings.customSoundPath = nil
        engine.loadCurrentSound()
        engine.fire()
        refreshUI()
    }

    @objc private func toggleRepeat() {
        Settings.fireOnRepeat.toggle()
        refreshUI()
    }

    @objc private func toggleModifiers() {
        Settings.fireOnModifiers.toggle()
        refreshUI()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("ShotgunKeystroke: launch-at-login change failed: \(error)")
            let alert = NSAlert()
            alert.messageText = "Couldn't change Launch at Login"
            alert.informativeText =
                "This only works when running from the built app bundle "
                + "(ShotgunKeystroke.app), not via `swift run`."
            alert.runModal()
        }
        refreshUI()
    }

    @objc private func openInputMonitoringSettings() {
        let url = URL(
            string:
                "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        )!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Key listening

    /// Observing global keyDown events requires the Input Monitoring
    /// permission (Accessibility is NOT enough on modern macOS —
    /// without Input Monitoring only modifier-key flagsChanged events
    /// are delivered).
    private var hasInputMonitoringAccess: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    private func requestInputMonitoringIfNeeded() {
        guard !hasInputMonitoringAccess else { return }
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    /// Keeps the tap in sync with the Input Monitoring permission.
    /// Without the permission, macOS still delivers modifier events to
    /// a tap but silently withholds normal keys — a confusing
    /// half-working state — so we only run a tap while access is
    /// genuinely granted, and retry every 2s otherwise so shots start
    /// the moment the user grants it. No relaunch needed.
    private func startEventTap() {
        if hasInputMonitoringAccess {
            if let tap = eventTap, !CFMachPortIsValid(tap) {
                teardownEventTap()
            }
            if eventTap == nil {
                installEventTap()
            }
            if eventTap != nil {
                tapRetryTimer?.invalidate()
                tapRetryTimer = nil
                refreshUI()
                return
            }
        } else if eventTap != nil {
            teardownEventTap()
            refreshUI()
        }
        if tapRetryTimer == nil {
            tapRetryTimer = Timer.scheduledTimer(
                withTimeInterval: 2.0, repeats: true
            ) { [weak self] _ in
                self?.startEventTap()
            }
        }
    }

    private func teardownEventTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }

    @discardableResult
    private func installEventTap() -> Bool {
        if eventTap != nil { return true }
        let mask =
            CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if let refcon {
                Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
                    .handleTap(type: type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }
        // Listen-only session tap: sees key events system-wide, can't
        // modify or block them. Creation fails (nil) until the user
        // grants Input Monitoring.
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: mask,
                callback: callback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else {
            return false
        }
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    /// Reacts to key events. Deliberately never reads key codes or
    /// characters — only "a key went down", the auto-repeat flag, and
    /// which modifier class changed.
    private func handleTap(type: CGEventType, event: CGEvent) {
        switch type {
        case .keyDown:
            guard Settings.isArmed else { return }
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if isRepeat && !Settings.fireOnRepeat { return }
            engine.fire()
        case .flagsChanged:
            let flags = event.flags.intersection(Self.trackedModifiers)
            let pressed = flags.subtracting(lastModifierFlags)
            lastModifierFlags = flags
            if Settings.isArmed && Settings.fireOnModifiers && !pressed.isEmpty {
                engine.fire()
            }
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        default:
            break
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Permission may have been granted or revoked since the last
        // check; resync the tap and the ⚠️ item.
        startEventTap()
        refreshUI()
    }
}
