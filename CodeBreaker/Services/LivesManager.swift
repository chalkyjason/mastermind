import Foundation
import SwiftUI

// MARK: - Lives Manager

class LivesManager: ObservableObject {
    static let shared = LivesManager()

    // MARK: - Configuration

    static let maxLives = 5
    static let regenerationTimeSeconds: TimeInterval = 30 * 60 // 30 minutes per life

    // MARK: - Published Properties

    @Published private(set) var lives: Int = LivesManager.maxLives
    @Published private(set) var nextLifeDate: Date?

    // MARK: - Private Properties

    private let defaults = UserDefaults.standard
    private var regenerationTimer: Timer?

    private enum Keys {
        static let lives = "playerLives"
        static let nextLifeDate = "nextLifeDate"
    }

    // MARK: - Computed Properties

    var hasLives: Bool {
        lives > 0
    }

    var isFull: Bool {
        lives >= Self.maxLives
    }

    var timeUntilNextLife: TimeInterval? {
        guard let nextDate = nextLifeDate, !isFull else { return nil }
        let remaining = nextDate.timeIntervalSinceNow
        return remaining > 0 ? remaining : 0
    }

    var formattedTimeUntilNextLife: String? {
        guard let time = timeUntilNextLife, time > 0 else { return nil }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Initialization

    init() {
        loadData()
        processOfflineRegeneration()
        startRegenerationTimer()
    }

    deinit {
        regenerationTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Use a life when player fails a level
    func useLife() {
        guard lives > 0 else { return }

        lives -= 1

        // Start regeneration timer if we just went below max
        if lives == Self.maxLives - 1 {
            nextLifeDate = Date().addingTimeInterval(Self.regenerationTimeSeconds)
        }

        HapticManager.shared.notification(.warning)
        saveData()

        #if DEBUG
        print("Lives: Used 1 life, \(lives) remaining")
        #endif
    }

    /// Add a life (from watching an ad)
    func addLife() {
        addLives(1)
    }

    /// Add multiple lives (from purchase or reward)
    func addLives(_ count: Int) {
        let previousLives = lives
        lives = min(lives + count, Self.maxLives)

        // Clear regeneration timer if now full
        if isFull {
            nextLifeDate = nil
        }

        if lives > previousLives {
            HapticManager.shared.notification(.success)
        }

        saveData()

        #if DEBUG
        print("Lives: Added \(count), now \(lives)")
        #endif
    }

    /// Refill all lives (from purchase)
    func refillAllLives() {
        lives = Self.maxLives
        nextLifeDate = nil
        HapticManager.shared.notification(.success)
        saveData()

        #if DEBUG
        print("Lives: Refilled to max (\(Self.maxLives))")
        #endif
    }

    // MARK: - Ad Reward Integration

    /// Called when user wants to watch an ad for a life
    /// Returns true if ad system is available and ad was watched
    func requestAdForLife(completion: @escaping (Bool) -> Void) {
        AdManager.shared.showRewardedAd { [weak self] success in
            if success {
                // User watched the ad and earned a reward
                self?.addLife()
                completion(true)
            } else {
                // User closed ad early or ad failed to load
                completion(false)
            }
        }
    }

    /// Check if ad reward is available
    var isAdAvailable: Bool {
        return AdManager.shared.isRewardedAdReady
    }

    // MARK: - Regeneration

    private func startRegenerationTimer() {
        regenerationTimer?.invalidate()
        regenerationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkRegeneration()
        }
    }

    private func checkRegeneration() {
        guard !isFull, let nextDate = nextLifeDate else { return }

        if Date() >= nextDate {
            // Regenerate a life
            lives += 1

            if isFull {
                nextLifeDate = nil
            } else {
                nextLifeDate = Date().addingTimeInterval(Self.regenerationTimeSeconds)
            }

            HapticManager.shared.notification(.success)
            saveData()

            #if DEBUG
            print("Lives: Regenerated 1 life, now \(lives)")
            #endif
        }

        // Force UI update for countdown
        objectWillChange.send()
    }

    private func processOfflineRegeneration() {
        guard !isFull, let nextDate = nextLifeDate else { return }

        let now = Date()
        guard now >= nextDate else { return }

        // Calculate how many lives to regenerate
        let timePassed = now.timeIntervalSince(nextDate)
        let livesToAdd = 1 + Int(timePassed / Self.regenerationTimeSeconds)
        let actualLivesToAdd = min(livesToAdd, Self.maxLives - lives)

        if actualLivesToAdd > 0 {
            lives += actualLivesToAdd

            if isFull {
                nextLifeDate = nil
            } else {
                // Calculate remaining time for next life
                let remainder = timePassed.truncatingRemainder(dividingBy: Self.regenerationTimeSeconds)
                nextLifeDate = now.addingTimeInterval(Self.regenerationTimeSeconds - remainder)
            }

            saveData()

            #if DEBUG
            print("Lives: Offline regeneration added \(actualLivesToAdd), now \(lives)")
            #endif
        }
    }

    // MARK: - Persistence

    private func saveData() {
        defaults.set(lives, forKey: Keys.lives)
        defaults.set(nextLifeDate, forKey: Keys.nextLifeDate)
    }

    private func loadData() {
        // Load lives (default to max if first launch)
        if defaults.object(forKey: Keys.lives) != nil {
            lives = defaults.integer(forKey: Keys.lives)
        } else {
            lives = Self.maxLives
        }

        // Load next life date
        nextLifeDate = defaults.object(forKey: Keys.nextLifeDate) as? Date
    }

    // MARK: - Debug

    #if DEBUG
    func debugSetLives(_ count: Int) {
        lives = min(max(0, count), Self.maxLives)
        if isFull {
            nextLifeDate = nil
        } else if nextLifeDate == nil {
            nextLifeDate = Date().addingTimeInterval(Self.regenerationTimeSeconds)
        }
        saveData()
    }

    func debugResetLives() {
        lives = Self.maxLives
        nextLifeDate = nil
        saveData()
    }
    #endif
}
