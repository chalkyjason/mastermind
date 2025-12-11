// SoundManager.swift
// Minimal implementation to silence 'Cannot find SoundManager' errors, matching usage in ContentView and SettingsView

import Foundation
import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    private static let soundKey = "soundEnabled"
    private var audioPlayer: AVAudioPlayer?
    
    private init() {
        // Default to enabled
        if UserDefaults.standard.object(forKey: Self.soundKey) == nil {
            UserDefaults.standard.set(true, forKey: Self.soundKey)
        }
    }
    
    func buttonTap() {
        guard Self.isEnabled else { return }
        // You can add real sound playback here if desired
        // Example: playSound(named: "buttonTap")
    }
    
    // Example stub for additional sounds
    func pegPlaced() { guard Self.isEnabled else { return } /* play sound */ }
    func guessSubmitted() { guard Self.isEnabled else { return } /* play sound */ }
    func pegRemoved() { guard Self.isEnabled else { return } /* play sound */ }
    func correctGuess() { guard Self.isEnabled else { return } /* play sound */ }
    func gameLost() { guard Self.isEnabled else { return } /* play sound */ }
    func starEarned() { guard Self.isEnabled else { return } /* play sound */ }
    
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: soundKey)
    }
    
    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: soundKey)
    }
    
    // Optional: stub for loading and playing sound files
    private func playSound(named name: String) {
        // This is a placeholder - add real sound playback if you wish
    }
}
