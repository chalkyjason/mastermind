import Foundation
import SwiftUI

// MARK: - Game Manager

class GameManager: ObservableObject {
    @Published var levels: [GameLevel] = []
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var totalStars: Int = 0
    @Published var levelsCompleted: Int = 0
    @Published var dailyChallenge: DailyChallenge?
    @Published var completedDailyChallenges: [DailyChallenge] = []
    
    private let defaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private enum Keys {
        static let levels = "savedLevels"
        static let currentStreak = "currentStreak"
        static let longestStreak = "longestStreak"
        static let lastPlayedDate = "lastPlayedDate"
        static let dailyChallenges = "completedDailyChallenges"
    }
    
    var hasDailyChallengeAvailable: Bool {
        guard let challenge = dailyChallenge else { return true }
        return !challenge.completed
    }
    
    // MARK: - Initialization
    
    init() {
        loadData()
        generateLevels()
        checkDailyChallenge()
        updateStreak()
    }
    
    // MARK: - Level Generation
    
    private func generateLevels() {
        // Only generate if we don't have saved levels
        guard levels.isEmpty else {
            calculateStats()
            return
        }
        
        var allLevels: [GameLevel] = []
        var levelId = 0
        
        for tier in DifficultyTier.allCases {
            for levelNum in 1...tier.levelsCount {
                let isUnlocked = tier == .tutorial && levelNum == 1
                let level = GameLevel(
                    id: levelId,
                    tier: tier,
                    levelInTier: levelNum,
                    isUnlocked: isUnlocked
                )
                allLevels.append(level)
                levelId += 1
            }
        }
        
        levels = allLevels
        saveData()
        calculateStats()
    }
    
    // MARK: - Level Progression
    
    func levels(for tier: DifficultyTier) -> [GameLevel] {
        levels.filter { $0.tier == tier }
    }
    
    func completeLevel(_ levelId: Int, stars: Int, attempts: Int) {
        guard let index = levels.firstIndex(where: { $0.id == levelId }) else { return }
        
        let previousStars = levels[index].stars
        
        // Update stars if better
        if stars > levels[index].stars {
            levels[index].stars = stars
        }
        
        // Update best attempts if better
        if let bestAttempts = levels[index].bestAttempts {
            if attempts < bestAttempts {
                levels[index].bestAttempts = attempts
            }
        } else {
            levels[index].bestAttempts = attempts
        }
        
        // Unlock next level
        if index + 1 < levels.count && !levels[index + 1].isUnlocked {
            levels[index + 1].isUnlocked = true

            // Check if we're unlocking a new tier
            let currentTier = levels[index].tier
            let nextTier = levels[index + 1].tier
            if currentTier != nextTier {
                HapticManager.shared.tierUnlocked()
            } else {
                HapticManager.shared.levelUnlocked()
            }
        }
        
        // Update streak
        updateStreakOnWin()

        // Recalculate stats
        calculateStats()

        // Save progress
        saveData()

        // Notify notification manager that user played
        NotificationManager.shared.userDidPlay()

        // Report to Game Center
        if stars > previousStars {
            GameCenterManager.shared.reportLevelCompletion(levelId: levelId, stars: stars)
        }
    }
    
    func unlockTier(_ tier: DifficultyTier) {
        // Unlock the first level of the tier
        if let index = levels.firstIndex(where: { $0.tier == tier && $0.levelInTier == 1 }) {
            levels[index].isUnlocked = true
            saveData()
        }
    }
    
    func isTierUnlocked(_ tier: DifficultyTier) -> Bool {
        levels.first(where: { $0.tier == tier })?.isUnlocked ?? false
    }
    
    func tierProgress(_ tier: DifficultyTier) -> (completed: Int, total: Int, stars: Int, maxStars: Int) {
        let tierLevels = levels(for: tier)
        let completed = tierLevels.filter { $0.stars > 0 }.count
        let stars = tierLevels.reduce(0) { $0 + $1.stars }
        let maxStars = tierLevels.count * 3
        return (completed, tierLevels.count, stars, maxStars)
    }
    
    // MARK: - Daily Challenge
    
    private func checkDailyChallenge() {
        let today = DailyChallenge.forToday()
        
        // Check if we already completed today's challenge
        if let completed = completedDailyChallenges.first(where: { 
            Calendar.current.isDate($0.date, inSameDayAs: today.date) 
        }) {
            dailyChallenge = completed
        } else {
            dailyChallenge = today
        }
    }
    
    func completeDailyChallenge(attempts: Int, stars: Int) {
        guard var challenge = dailyChallenge else { return }
        
        challenge.completed = true
        challenge.attempts = attempts
        challenge.stars = stars
        
        dailyChallenge = challenge
        completedDailyChallenges.append(challenge)

        // Update streak
        updateStreakOnWin()

        saveData()

        // Notify notification manager that user played
        NotificationManager.shared.userDidPlay()

        // Report to Game Center
        GameCenterManager.shared.reportDailyChallengeCompletion(stars: stars)
    }
    
    // MARK: - Streak Management
    
    private func updateStreak() {
        let lastPlayed = defaults.object(forKey: Keys.lastPlayedDate) as? Date
        let calendar = Calendar.current
        
        if let last = lastPlayed {
            let daysSinceLastPlay = calendar.dateComponents([.day], from: last, to: Date()).day ?? 0
            
            if daysSinceLastPlay > 1 {
                // Streak broken
                currentStreak = 0
            }
        }
    }
    
    private func updateStreakOnWin() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastPlayed = defaults.object(forKey: Keys.lastPlayedDate) as? Date

        if let last = lastPlayed {
            let lastDay = calendar.startOfDay(for: last)

            if lastDay == today {
                // Already played today, no streak update
                return
            } else if calendar.isDate(lastDay, equalTo: calendar.date(byAdding: .day, value: -1, to: today)!, toGranularity: .day) {
                // Played yesterday, increment streak
                currentStreak += 1
            } else {
                // Gap in days, reset streak
                currentStreak = 1
            }
        } else {
            // First time playing
            currentStreak = 1
        }

        // Check for streak milestones and trigger haptic celebrations
        let milestones = [3, 7, 14, 30]
        if milestones.contains(currentStreak) {
            HapticManager.shared.streakMilestone(currentStreak)
        }

        // Update longest streak
        if currentStreak > longestStreak {
            longestStreak = currentStreak
            GameCenterManager.shared.reportStreak(longestStreak)
        }

        defaults.set(today, forKey: Keys.lastPlayedDate)
    }
    
    // MARK: - Stats
    
    private func calculateStats() {
        totalStars = levels.reduce(0) { $0 + $1.stars }
        levelsCompleted = levels.filter { $0.stars > 0 }.count
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        // Save levels
        if let encoded = try? JSONEncoder().encode(levels) {
            defaults.set(encoded, forKey: Keys.levels)
        }
        
        // Save streak
        defaults.set(currentStreak, forKey: Keys.currentStreak)
        defaults.set(longestStreak, forKey: Keys.longestStreak)
        
        // Save daily challenges
        if let encoded = try? JSONEncoder().encode(completedDailyChallenges) {
            defaults.set(encoded, forKey: Keys.dailyChallenges)
        }
    }
    
    private func loadData() {
        // Load levels
        if let data = defaults.data(forKey: Keys.levels),
           let decoded = try? JSONDecoder().decode([GameLevel].self, from: data) {
            levels = decoded
        }
        
        // Load streak
        currentStreak = defaults.integer(forKey: Keys.currentStreak)
        longestStreak = defaults.integer(forKey: Keys.longestStreak)
        
        // Load daily challenges
        if let data = defaults.data(forKey: Keys.dailyChallenges),
           let decoded = try? JSONDecoder().decode([DailyChallenge].self, from: data) {
            completedDailyChallenges = decoded
        }
    }
    
    // MARK: - Debug/Reset
    
    func resetAllProgress() {
        levels = []
        currentStreak = 0
        longestStreak = 0
        totalStars = 0
        levelsCompleted = 0
        completedDailyChallenges = []
        
        defaults.removeObject(forKey: Keys.levels)
        defaults.removeObject(forKey: Keys.currentStreak)
        defaults.removeObject(forKey: Keys.longestStreak)
        defaults.removeObject(forKey: Keys.lastPlayedDate)
        defaults.removeObject(forKey: Keys.dailyChallenges)
        
        generateLevels()
        checkDailyChallenge()
    }
}
