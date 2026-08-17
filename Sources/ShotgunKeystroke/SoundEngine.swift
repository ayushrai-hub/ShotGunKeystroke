import AVFoundation
import Foundation

/// Plays the blast. Keeps a small pool of players so rapid typing
/// overlaps blasts instead of cutting the previous one short.
final class SoundEngine {
    private static let poolSize = 8

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
        loadCurrentSound()
    }

    /// Loads the user's custom sound if one is set (falling back to the
    /// built-in blast if it's missing or unreadable).
    func loadCurrentSound() {
        if let path = Settings.customSoundPath {
            if load(url: URL(fileURLWithPath: path)) { return }
            NSLog("ShotgunKeystroke: custom sound unreadable, using built-in: \(path)")
        }
        if let url = SoundEngine.locateDefaultSound() {
            load(url: url)
        } else {
            NSLog("ShotgunKeystroke: shotgun.wav not found — no sound will play")
        }
    }

    /// Swaps the player pool to a new sound file. Returns false (and
    /// keeps the current sound) if the file can't be decoded.
    @discardableResult
    func load(url: URL) -> Bool {
        var newPlayers: [AVAudioPlayer] = []
        for _ in 0..<SoundEngine.poolSize {
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return false }
            player.volume = volume
            player.prepareToPlay()
            newPlayers.append(player)
        }
        players = newPlayers
        nextIndex = 0
        return true
    }

    func fire() {
        guard !players.isEmpty else { return }
        let player = players[nextIndex]
        nextIndex = (nextIndex + 1) % players.count
        player.currentTime = 0
        player.play()
    }

    private static func locateDefaultSound() -> URL? {
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
