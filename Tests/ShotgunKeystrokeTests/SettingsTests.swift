import Foundation
import Testing

@testable import ShotgunKeystroke

/// Settings is backed by UserDefaults.standard, which inside `swift test`
/// is the test runner's domain — not the installed app's. Each test still
/// snapshots and restores the keys it touches, and the suite is serialized
/// because the tests share that one defaults store.
@Suite(.serialized)
struct SettingsTests {
    private static let keys = [
        "isArmed", "volume", "fireOnRepeat", "fireOnModifiers", "customSoundPath",
    ]

    private func withCleanDefaults(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let saved = Self.keys.map { ($0, defaults.object(forKey: $0)) }
        Self.keys.forEach { defaults.removeObject(forKey: $0) }
        defer {
            for (key, value) in saved {
                if let value {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        try body()
    }

    @Test func defaultsMatchDocumentedBehavior() {
        withCleanDefaults {
            #expect(Settings.isArmed == true)
            #expect(Settings.volume == 0.6)
            #expect(Settings.fireOnRepeat == false)
            #expect(Settings.fireOnModifiers == false)
            #expect(Settings.customSoundPath == nil)
        }
    }

    @Test(arguments: [
        (Float(-1.0), Float(0.1)),
        (0.0, 0.1),
        (0.1, 0.1),
        (0.37, 0.37),
        (1.0, 1.0),
        (5.0, 1.0),
    ])
    func volumeIsClampedTo10Through100Percent(input: Float, expected: Float) {
        withCleanDefaults {
            Settings.volume = input
            #expect(Settings.volume == expected)
        }
    }

    @Test func togglesPersist() {
        withCleanDefaults {
            Settings.isArmed = false
            Settings.fireOnRepeat = true
            Settings.fireOnModifiers = true
            #expect(Settings.isArmed == false)
            #expect(Settings.fireOnRepeat == true)
            #expect(Settings.fireOnModifiers == true)
        }
    }

    @Test func customSoundPathRoundTripsAndClears() {
        withCleanDefaults {
            Settings.customSoundPath = "/tmp/duck.wav"
            #expect(Settings.customSoundPath == "/tmp/duck.wav")
            Settings.customSoundPath = nil
            #expect(Settings.customSoundPath == nil)
        }
    }
}
