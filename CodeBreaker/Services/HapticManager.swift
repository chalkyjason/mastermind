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

    // MARK: - Enhanced Haptic Touch

    /// Long press feedback - provides continuous haptic during press
    func longPressStart() {
        impact(.medium)
    }

    func longPressEnd() {
        impact(.light)
    }

    /// Locked item feedback - subtle indication that something is locked
    func lockedItemTap() {
        impact(.rigid)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.impact(.soft)
        }
    }

    /// Level unlocked celebration - satisfying unlock pattern
    func levelUnlocked() {
        impact(.medium)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.impact(.light)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.notification(.success)
        }
    }

    /// Tier unlocked celebration - bigger celebration for tier unlock
    func tierUnlocked() {
        notification(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.impact(.heavy)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.impact(.medium)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.impact(.light)
        }
    }

    /// Streak milestone celebration - special pattern for milestone days
    func streakMilestone(_ days: Int) {
        guard isEnabled else { return }

        // Different patterns based on milestone
        switch days {
        case 3:
            // Triple tap
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) { [weak self] in
                    self?.impact(.medium)
                }
            }
        case 7:
            // Week celebration - rising intensity
            notification(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.impact(.light)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.impact(.medium)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.impact(.heavy)
            }
        case 14:
            // Two week celebration - double pattern
            for i in 0..<2 {
                let baseDelay = Double(i) * 0.4
                DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay) { [weak self] in
                    self?.notification(.success)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay + 0.15) { [weak self] in
                    self?.impact(.heavy)
                }
            }
        case 30:
            // Month celebration - grand finale pattern
            notification(.success)
            for i in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Double(i) * 0.12) { [weak self] in
                    self?.impact(.heavy)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                self?.notification(.success)
            }
        default:
            notification(.success)
        }
    }

    /// Color picker haptic - subtle feedback when selecting colors
    func colorSelected() {
        impact(.medium)
    }

    /// Button press differentiation
    func primaryButtonTap() {
        impact(.medium)
    }

    func secondaryButtonTap() {
        impact(.light)
    }

    func destructiveButtonTap() {
        impact(.rigid)
    }

    /// Navigation haptic - subtle feedback for screen transitions
    func navigate() {
        impact(.light)
    }

    /// Replay/restart game haptic
    func gameRestart() {
        impact(.medium)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.impact(.light)
        }
    }

    /// Perfect game celebration - all stars earned with minimal attempts
    func perfectGame() {
        notification(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.impact(.heavy)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.impact(.heavy)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.notification(.success)
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
