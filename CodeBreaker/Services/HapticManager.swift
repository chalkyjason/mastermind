import UIKit

// MARK: - Haptic Manager

class HapticManager {
    static let shared = HapticManager()
    
    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }
    
    private init() {
        // Set default to enabled
        if UserDefaults.standard.object(forKey: "hapticsEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "hapticsEnabled")
        }
    }
    
    // MARK: - Impact Feedback
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    // MARK: - Notification Feedback
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    // MARK: - Selection Feedback
    
    func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    // MARK: - Game-Specific Haptics
    
    func pegPlaced() {
        impact(.medium)
    }
    
    func pegRemoved() {
        impact(.light)
    }
    
    func guessSubmitted() {
        impact(.heavy)
    }
    
    func correctGuess() {
        // Success pattern: light, pause, medium, pause, heavy
        notification(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.impact(.medium)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.impact(.heavy)
        }
    }
    
    func wrongGuess() {
        notification(.warning)
    }
    
    func gameLost() {
        notification(.error)
    }
    
    func starEarned() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.impact(.light)
        }
    }
    
    func blackPegFeedback() {
        impact(.rigid)
    }
    
    func whitePegFeedback() {
        impact(.soft)
    }
    
    func feedbackReveal(blackCount: Int, whiteCount: Int) {
        // Reveal feedback pegs one at a time with haptics
        var delay: Double = 0
        
        for _ in 0..<blackCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.blackPegFeedback()
            }
            delay += 0.15
        }
        
        for _ in 0..<whiteCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.whitePegFeedback()
            }
            delay += 0.15
        }
    }
}

// MARK: - Settings

extension HapticManager {
    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "hapticsEnabled")
    }
    
    static var enabled: Bool {
        UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }
}
