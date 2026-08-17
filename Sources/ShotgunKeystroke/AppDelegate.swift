import AppKit
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var engine: SoundEngine!
    private var monitors: [Any] = []
    private var lastModifierFlags: NSEvent.ModifierFlags = []

    private var toggleItem: NSMenuItem!
    private var volumeLabelItem: NSMenuItem!
    private var volumeSlider: NSSlider!
    private var repeatItem: NSMenuItem!
    private var modifiersItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var accessibilityItem: NSMenuItem!

    private static let trackedModifiers: NSEvent.ModifierFlags = [
        .shift, .control, .option, .command, .capsLock,
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine = SoundEngine(volume: Settings.volume)
        setupStatusItem()
        requestAccessibilityIfNeeded()
        installMonitors()
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

        accessibilityItem = NSMenuItem(
            title: "⚠️ Grant Accessibility Access…",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

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

        repeatItem.state = Settings.fireOnRepeat ? .on : .off
        modifiersItem.state = Settings.fireOnModifiers ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

        accessibilityItem.isHidden = AXIsProcessTrusted()
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

    @objc private func openAccessibilitySettings() {
        let url = URL(
            string:
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Key listening

    private func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func installMonitors() {
        // Global monitor: keystrokes in every other app.
        if let global = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .flagsChanged],
            handler: { [weak self] event in
                self?.handle(event)
            }
        ) {
            monitors.append(global)
        }
        // Local monitor: keystrokes while our own menu is focused.
        if let local = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged],
            handler: { [weak self] event in
                self?.handle(event)
                return event
            }
        ) {
            monitors.append(local)
        }
    }

    /// Reacts to key events. Deliberately never reads key codes or
    /// characters — the only thing this app knows is "a key went down".
    private func handle(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            guard Settings.isArmed else { return }
            if event.isARepeat && !Settings.fireOnRepeat { return }
            engine.fire()
        case .flagsChanged:
            let flags = event.modifierFlags.intersection(Self.trackedModifiers)
            let pressed = flags.subtracting(lastModifierFlags)
            lastModifierFlags = flags
            if Settings.isArmed && Settings.fireOnModifiers && !pressed.isEmpty {
                engine.fire()
            }
        default:
            break
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Accessibility may have been granted since launch; keep the menu honest.
        refreshUI()
    }
}
