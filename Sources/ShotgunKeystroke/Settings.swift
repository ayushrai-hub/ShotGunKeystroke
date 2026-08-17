import Foundation

/// Persisted user preferences. Everything survives app restarts.
enum Settings {
    private static let defaults = UserDefaults.standard

    /// Master switch — is the shotgun armed?
    static var isArmed: Bool {
        get { defaults.object(forKey: "isArmed") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "isArmed") }
    }

    /// Volume, clamped to 0.1 ... 1.0 (10% – 100%).
    static var volume: Float {
        get { clamp(defaults.object(forKey: "volume") as? Float ?? 0.6) }
        set { defaults.set(clamp(newValue), forKey: "volume") }
    }

    /// Fire on key auto-repeat while a key is held down.
    static var fireOnRepeat: Bool {
        get { defaults.object(forKey: "fireOnRepeat") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "fireOnRepeat") }
    }

    /// Fire when a modifier key (⇧ ⌘ ⌥ ⌃) is pressed.
    static var fireOnModifiers: Bool {
        get { defaults.object(forKey: "fireOnModifiers") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "fireOnModifiers") }
    }

    private static func clamp(_ value: Float) -> Float {
        min(max(value, 0.1), 1.0)
    }
}
