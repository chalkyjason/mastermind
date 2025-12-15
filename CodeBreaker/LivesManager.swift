import Foundation
import SwiftUI

// MARK: - Lives Manager

class LivesManager: ObservableObject {
    static let shared = LivesManager()
    
    @Published var lives: Int = 5
    @Published var nextLifeTime: Date?
    
    static let maxLives = 5
    private let lifeRegenerationMinutes = 30
    private let defaults = UserDefaults.standard
    
    private var timer: Timer?
    
    // Keys for UserDefaults
    private enum Keys {
        static let lives = "currentLives"
        static let nextLifeTime = "nextLifeTime"
    }
    
    var hasLives: Bool {
        lives > 0
    }
    
    var formattedTimeUntilNextLife: String? {
        guard lives < Self.maxLives, let nextLife = nextLifeTime else { return nil }
        
        let now = Date()
        guard nextLife > now else {
            regenerateLife()
            return nil
        }
        
        let timeInterval = nextLife.timeIntervalSince(now)
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Initialization
    
    private init() {
        loadData()
        checkLifeRegeneration()
        startTimer()
    }
    
    // MARK: - Life Management
    
    func useLife() {
        guard lives > 0 else { return }
        
        lives -= 1
        
        // Start regeneration timer if we just went below max lives
        if lives < Self.maxLives && nextLifeTime == nil {
            scheduleNextLife()
        }
        
        saveData()
    }
    
    func addLife() {
        guard lives < Self.maxLives else { return }
        
        lives += 1
        
        if lives >= Self.maxLives {
            nextLifeTime = nil
            stopTimer()
        } else if nextLifeTime == nil {
            scheduleNextLife()
        }
        
        saveData()
    }
    
    private func scheduleNextLife() {
        nextLifeTime = Date().addingTimeInterval(TimeInterval(lifeRegenerationMinutes * 60))
        saveData()
    }
    
    private func checkLifeRegeneration() {
        guard lives < Self.maxLives else {
            nextLifeTime = nil
            return
        }
        
        guard let nextLife = nextLifeTime else {
            scheduleNextLife()
            return
        }
        
        let now = Date()
        while nextLife <= now && lives < Self.maxLives {
            regenerateLife()
        }
    }
    
    private func regenerateLife() {
        guard lives < Self.maxLives else {
            nextLifeTime = nil
            stopTimer()
            saveData()
            return
        }
        
        lives += 1
        
        if lives < Self.maxLives {
            scheduleNextLife()
        } else {
            nextLifeTime = nil
            stopTimer()
        }
        
        saveData()
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        guard lives < Self.maxLives else { return }
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkLifeRegeneration()
            self?.objectWillChange.send()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        defaults.set(lives, forKey: Keys.lives)
        defaults.set(nextLifeTime, forKey: Keys.nextLifeTime)
    }
    
    private func loadData() {
        lives = defaults.integer(forKey: Keys.lives)
        if lives == 0 {
            lives = Self.maxLives // First launch
        }
        nextLifeTime = defaults.object(forKey: Keys.nextLifeTime) as? Date
    }
    
    // MARK: - App Lifecycle
    
    func appDidBecomeActive() {
        checkLifeRegeneration()
        startTimer()
    }
    
    func appDidEnterBackground() {
        stopTimer()
        saveData()
    }
    
    // MARK: - Debug/Reset
    
    func resetLives() {
        lives = Self.maxLives
        nextLifeTime = nil
        stopTimer()
        saveData()
    }
}
