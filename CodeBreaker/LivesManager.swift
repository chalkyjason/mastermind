import Foundation
import SwiftUI

class LivesManager: ObservableObject {
    static let shared = LivesManager()
    
    static let maxLives = 5
    
    @Published var lives: Int = maxLives
    @Published var isAdAvailable: Bool = false // Simulate ad availability
    
    private var timer: Timer?
    private var nextRefill: Date?
    
    var hasLives: Bool {
        lives > 0
    }
    
    var isFull: Bool {
        lives >= Self.maxLives
    }
    
    var formattedTimeUntilNextLife: String? {
        guard let next = nextRefill, lives < Self.maxLives else { return nil }
        let interval = Int(next.timeIntervalSinceNow)
        guard interval > 0 else { return nil }
        let minutes = interval / 60
        let seconds = interval % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private init() {
        // For demo/testing, always have lives on launch
        lives = Self.maxLives
        startTimerIfNeeded()
    }
    
    func useLife() {
        guard lives > 0 else { return }
        lives -= 1
        if lives < Self.maxLives && nextRefill == nil {
            scheduleNextRefill()
        }
    }
    
    func requestAdForLife(completion: @escaping (Bool) -> Void) {
        // Simulate ad watching process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.lives = min(self.lives + 1, Self.maxLives)
            completion(true)
        }
    }
    
    private func scheduleNextRefill() {
        nextRefill = Date().addingTimeInterval(60 * 30) // 30 mins
        startTimerIfNeeded()
    }
    
    private func startTimerIfNeeded() {
        timer?.invalidate()
        guard lives < Self.maxLives else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkRefill()
        }
    }
    
    private func checkRefill() {
        guard let next = nextRefill else { return }
        if Date() >= next {
            lives = min(lives + 1, Self.maxLives)
            if lives < Self.maxLives {
                scheduleNextRefill()
            } else {
                nextRefill = nil
                timer?.invalidate()
            }
        }
        objectWillChange.send()
    }
    
    // Debug/testing controls for Settings
    #if DEBUG
    func debugSetLives(_ value: Int) {
        lives = max(0, min(value, Self.maxLives))
        if lives < Self.maxLives {
            scheduleNextRefill()
        } else {
            nextRefill = nil
            timer?.invalidate()
        }
    }
    
    func debugResetLives() {
        lives = Self.maxLives
        nextRefill = nil
        timer?.invalidate()
    }
    #endif
}
