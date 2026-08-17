import AVFoundation
import Foundation

/// Plays the shotgun blast. Keeps a small pool of players so rapid
/// typing overlaps blasts instead of cutting the previous one short.
final class SoundEngine {
    private var players: [AVAudioPlayer] = []
    private var nextIndex = 0

    var volume: Float {
        didSet {
            for player in players {
                player.volume = volume
            }
        }
    }

    init(volume: Float) {
        self.volume = volume
        guard let url = SoundEngine.locateSound() else {
            NSLog("ShotgunKeystroke: shotgun.wav not found — no sound will play")
            return
        }
        for _ in 0..<8 {
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.volume = volume
                player.prepareToPlay()
                players.append(player)
            }
        }
    }

    func fire() {
        guard !players.isEmpty else { return }
        let player = players[nextIndex]
        nextIndex = (nextIndex + 1) % players.count
        player.currentTime = 0
        player.play()
    }

    private static func locateSound() -> URL? {
        // Normal case: running from the .app bundle.
        if let url = Bundle.main.url(forResource: "shotgun", withExtension: "wav") {
            return url
        }
        // Development fallback for `swift run`: next to the executable,
        // or in the repo's Resources directory.
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("shotgun.wav"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/shotgun.wav"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
