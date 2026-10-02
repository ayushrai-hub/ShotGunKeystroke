import Foundation
import Testing

@testable import ShotgunKeystroke

/// These tests only load audio; they never call `fire()`, so running the
/// suite is silent.
struct SoundEngineTests {
    private static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static let builtInSound = packageRoot.appendingPathComponent("Resources/shotgun.wav")

    @Test func loadsTheBuiltInShotgunSound() {
        let engine = SoundEngine(volume: 0.5)
        #expect(engine.load(url: Self.builtInSound))
    }

    @Test func rejectsFilesThatAreNotAudio() throws {
        let notAudio = FileManager.default.temporaryDirectory
            .appendingPathComponent("shotgunkeystroke-not-audio-\(UUID().uuidString).wav")
        try Data("definitely not a wav file".utf8).write(to: notAudio)
        defer { try? FileManager.default.removeItem(at: notAudio) }

        let engine = SoundEngine(volume: 0.5)
        #expect(engine.load(url: notAudio) == false)
    }

    @Test func rejectsMissingFiles() {
        let missing = URL(fileURLWithPath: "/nonexistent/shotgunkeystroke/\(UUID().uuidString).wav")
        let engine = SoundEngine(volume: 0.5)
        #expect(engine.load(url: missing) == false)
    }

    @Test func volumeChangesAreAccepted() {
        let engine = SoundEngine(volume: 0.2)
        engine.volume = 0.9
        #expect(engine.volume == 0.9)
    }
}
