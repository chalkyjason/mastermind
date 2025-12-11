import AVFoundation
import UIKit

// MARK: - Sound Manager

class SoundManager {
    static let shared = SoundManager()

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "soundEnabled")
    }

    private var audioPlayers: [String: AVAudioPlayer] = [:]

    private init() {
        // Set default to enabled
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "soundEnabled")
        }
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    // MARK: - Sound Playback

    private func playSystemSound(_ soundID: SystemSoundID) {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(soundID)
    }

    // MARK: - Game-Specific Sounds

    func pegPlaced() {
        // Use a subtle click sound
        playSystemSound(1104) // Tock sound
    }

    func pegRemoved() {
        // Use a softer click
        playSystemSound(1105) // Tock sound (softer)
    }

    func guessSubmitted() {
        // Use a confirmation sound
        playSystemSound(1103) // Mail sent sound
    }

    func correctGuess() {
        // Success pattern: play ascending tones
        playSystemSound(1057) // SMS Received 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.playSystemSound(1054) // SMS Received 4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.playSystemSound(1108) // Anticipate
        }
    }

    func wrongGuess() {
        // Gentle error sound
        playSystemSound(1053) // SMS Received 3
    }

    func gameLost() {
        // Failure sound
        playSystemSound(1006) // Tink
    }

    func starEarned() {
        // Reward sound
        playSystemSound(1054) // SMS Received 4
    }

    func levelComplete() {
        // Achievement sound
        playSystemSound(1108) // Anticipate
    }

    func buttonTap() {
        // UI interaction sound
        playSystemSound(1104) // Tock
    }

    func navigation() {
        // Screen transition sound
        playSystemSound(1105) // Tock (soft)
    }

    // MARK: - Settings

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "soundEnabled")
    }

    static var enabled: Bool {
        UserDefaults.standard.bool(forKey: "soundEnabled")
    }
}
