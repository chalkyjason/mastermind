import AVFoundation

/// Manages sound effects throughout the app
final class SoundManager {
    static let shared = SoundManager()
    
    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "soundEnabled")
    }
    
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    
    private init() {
        // Initialize with sound enabled by default
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "soundEnabled")
        }
    }
    
    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "soundEnabled")
    }
    
    // MARK: - Sound Effects
    
    func pegPlaced() {
        playSound(named: "peg_placed", type: "wav")
    }
    
    func pegRemoved() {
        playSound(named: "peg_removed", type: "wav")
    }
    
    func guessSubmitted() {
        playSound(named: "guess_submitted", type: "wav")
    }
    
    func correctGuess() {
        playSound(named: "correct_guess", type: "wav")
    }
    
    func gameLost() {
        playSound(named: "game_lost", type: "wav")
    }
    
    func buttonTap() {
        playSound(named: "button_tap", type: "wav")
    }
    
    // MARK: - Private Methods
    
    private func playSound(named name: String, type: String) {
        guard isEnabled else { return }
        
        // Try to play the sound if it exists
        if let url = Bundle.main.url(forResource: name, withExtension: type) {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                player.play()
                
                // Store player to keep it alive during playback
                audioPlayers[name] = player
                
                // Clean up after playback
                DispatchQueue.main.asyncAfter(deadline: .now() + player.duration) {
                    self.audioPlayers.removeValue(forKey: name)
                }
            } catch {
                print("Error playing sound \(name): \(error.localizedDescription)")
            }
        } else {
            // Silently fail if sound file doesn't exist
            // This allows the app to work without sound files
        }
    }
}
