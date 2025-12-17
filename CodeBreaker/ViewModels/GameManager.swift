import Foundation
import SwiftUI
import WidgetKit

// MARK: - Game Manager

class GameManager: ObservableObject {
    @Published var levels: [GameLevel] = []
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var totalStars: Int = 0
    @Published var levelsCompleted: Int = 0
    @Published var dailyChallenge: DailyChallenge?
    @Published var completedDailyChallenges: [DailyChallenge] = []

    // Ball Sort
    @Published var ballSortLevels: [BallSortLevel] = []
    @Published var ballSortTotalStars: Int = 0
    @Published var ballSortLevelsCompleted: Int = 0

    // Binary Grid
    @Published var binaryGridLevels: [BinaryGridLevel] = []
    @Published var binaryGridTotalStars: Int = 0
    @Published var binaryGridLevelsCompleted: Int = 0

    // Hints
    @Published var hintsUsedToday: Int = 0
    static let maxDailyHints = 3

    private let defaults = UserDefaults.standard

    // Keys for UserDefaults
    private enum Keys {
        static let levels = "savedLevels"
        static let currentStreak = "currentStreak"
        static let longestStreak = "longestStreak"
        static let lastPlayedDate = "lastPlayedDate"
        static let dailyChallenges = "completedDailyChallenges"
        static let ballSortLevels = "ballSortLevels"
        static let binaryGridLevels = "binaryGridLevels"
        static let hintsUsedToday = "hintsUsedToday"
        static let lastHintDate = "lastHintDate"
    }

    // MARK: - Hint Properties

    var hintsRemaining: Int {
        max(0, Self.maxDailyHints - hintsUsedToday)
    }

    var canUseHint: Bool {
        hintsRemaining > 0
    }
    
    var hasDailyChallengeAvailable: Bool {
        guard let challenge = dailyChallenge else { return true }
        return !challenge.completed
    }
    
    // MARK: - Initialization

    init() {
        loadData()
        generateLevels()
        generateBallSortLevels()
        generateBinaryGridLevels()
        checkDailyChallenge()
        updateStreak()
        checkHintReset()
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

    // MARK: - Ball Sort Level Generation

    private func generateBallSortLevels() {
        // Only generate if we don't have saved levels
        guard ballSortLevels.isEmpty else {
            calculateBallSortStats()
            return
        }

        var allLevels: [BallSortLevel] = []
        var levelId = 0

        for difficulty in BallSortDifficulty.allCases {
            for levelNum in 1...difficulty.levelsCount {
                let isUnlocked = difficulty == .easy && levelNum == 1
                let level = BallSortLevel(
                    id: levelId,
                    difficulty: difficulty,
                    levelInDifficulty: levelNum,
                    isUnlocked: isUnlocked
                )
                allLevels.append(level)
                levelId += 1
            }
        }

        ballSortLevels = allLevels
        saveData()
        calculateBallSortStats()
    }

    // MARK: - Ball Sort Level Progression

    func ballSortLevels(for difficulty: BallSortDifficulty) -> [BallSortLevel] {
        ballSortLevels.filter { $0.difficulty == difficulty }
    }

    func completeBallSortLevel(_ levelId: Int, stars: Int, moves: Int) {
        guard let index = ballSortLevels.firstIndex(where: { $0.id == levelId }) else { return }

        let previousStars = ballSortLevels[index].stars

        // Update stars if better
        if stars > ballSortLevels[index].stars {
            ballSortLevels[index].stars = stars
        }

        // Update best moves if better
        if let bestMoves = ballSortLevels[index].bestMoves {
            if moves < bestMoves {
                ballSortLevels[index].bestMoves = moves
            }
        } else {
            ballSortLevels[index].bestMoves = moves
        }

        // Unlock next level
        if index + 1 < ballSortLevels.count && !ballSortLevels[index + 1].isUnlocked {
            ballSortLevels[index + 1].isUnlocked = true

            // Check if we're unlocking a new difficulty
            let currentDifficulty = ballSortLevels[index].difficulty
            let nextDifficulty = ballSortLevels[index + 1].difficulty
            if currentDifficulty != nextDifficulty {
                HapticManager.shared.tierUnlocked()
            } else {
                HapticManager.shared.levelUnlocked()
            }
        }

        // Update streak
        updateStreakOnWin()

        // Recalculate stats
        calculateBallSortStats()

        // Save progress
        saveData()

        // Notify notification manager that user played
        NotificationManager.shared.userDidPlay()

        // Report to Game Center
        if stars > previousStars {
            GameCenterManager.shared.reportBallSortCompletion(levelId: levelId, stars: stars)
        }
    }

    func isBallSortDifficultyUnlocked(_ difficulty: BallSortDifficulty) -> Bool {
        ballSortLevels.first(where: { $0.difficulty == difficulty })?.isUnlocked ?? false
    }

    func ballSortDifficultyProgress(_ difficulty: BallSortDifficulty) -> (completed: Int, total: Int, stars: Int, maxStars: Int) {
        let difficultyLevels = ballSortLevels(for: difficulty)
        let completed = difficultyLevels.filter { $0.stars > 0 }.count
        let stars = difficultyLevels.reduce(0) { $0 + $1.stars }
        let maxStars = difficultyLevels.count * 3
        return (completed, difficultyLevels.count, stars, maxStars)
    }

    private func calculateBallSortStats() {
        ballSortTotalStars = ballSortLevels.reduce(0) { $0 + $1.stars }
        ballSortLevelsCompleted = ballSortLevels.filter { $0.stars > 0 }.count
    }

    // MARK: - Binary Grid Level Generation

    private func generateBinaryGridLevels() {
        guard binaryGridLevels.isEmpty else {
            calculateBinaryGridStats()
            return
        }

        var allLevels: [BinaryGridLevel] = []
        var levelId = 0

        for difficulty in BinaryGridDifficulty.allCases {
            for levelNum in 1...difficulty.levelsCount {
                let isUnlocked = difficulty == .tiny && levelNum == 1
                let level = BinaryGridLevel(
                    id: levelId,
                    difficulty: difficulty,
                    levelInDifficulty: levelNum,
                    isUnlocked: isUnlocked
                )
                allLevels.append(level)
                levelId += 1
            }
        }

        binaryGridLevels = allLevels
        saveData()
        calculateBinaryGridStats()
    }

    // MARK: - Binary Grid Level Progression

    func binaryGridLevels(for difficulty: BinaryGridDifficulty) -> [BinaryGridLevel] {
        binaryGridLevels.filter { $0.difficulty == difficulty }
    }

    func completeBinaryGridLevel(_ levelId: Int, stars: Int, time: TimeInterval) {
        guard let index = binaryGridLevels.firstIndex(where: { $0.id == levelId }) else { return }

        let previousStars = binaryGridLevels[index].stars

        // Update stars if better
        if stars > binaryGridLevels[index].stars {
            binaryGridLevels[index].stars = stars
        }

        // Update best time if better
        if let bestTime = binaryGridLevels[index].bestTime {
            if time < bestTime {
                binaryGridLevels[index].bestTime = time
            }
        } else {
            binaryGridLevels[index].bestTime = time
        }

        // Unlock next level
        if index + 1 < binaryGridLevels.count && !binaryGridLevels[index + 1].isUnlocked {
            binaryGridLevels[index + 1].isUnlocked = true

            let currentDifficulty = binaryGridLevels[index].difficulty
            let nextDifficulty = binaryGridLevels[index + 1].difficulty
            if currentDifficulty != nextDifficulty {
                HapticManager.shared.tierUnlocked()
            } else {
                HapticManager.shared.levelUnlocked()
            }
        }

        // Update streak
        updateStreakOnWin()

        // Recalculate stats
        calculateBinaryGridStats()

        // Save progress
        saveData()

        // Notify notification manager
        NotificationManager.shared.userDidPlay()

        // Report to Game Center
        if stars > previousStars {
            GameCenterManager.shared.reportBinaryGridCompletion(levelId: levelId, stars: stars)
        }
    }

    func isBinaryGridDifficultyUnlocked(_ difficulty: BinaryGridDifficulty) -> Bool {
        binaryGridLevels.first(where: { $0.difficulty == difficulty })?.isUnlocked ?? false
    }

    func binaryGridDifficultyProgress(_ difficulty: BinaryGridDifficulty) -> (completed: Int, total: Int, stars: Int, maxStars: Int) {
        let difficultyLevels = binaryGridLevels(for: difficulty)
        let completed = difficultyLevels.filter { $0.stars > 0 }.count
        let stars = difficultyLevels.reduce(0) { $0 + $1.stars }
        let maxStars = difficultyLevels.count * 3
        return (completed, difficultyLevels.count, stars, maxStars)
    }

    private func calculateBinaryGridStats() {
        binaryGridTotalStars = binaryGridLevels.reduce(0) { $0 + $1.stars }
        binaryGridLevelsCompleted = binaryGridLevels.filter { $0.stars > 0 }.count
    }

    // MARK: - Hint Management

    /// Checks if hints should be reset (new day)
    private func checkHintReset() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastHintDate = defaults.object(forKey: Keys.lastHintDate) as? Date {
            let lastDay = calendar.startOfDay(for: lastHintDate)
            if lastDay < today {
                // New day, reset hints
                hintsUsedToday = 0
                defaults.set(0, forKey: Keys.hintsUsedToday)
                defaults.set(today, forKey: Keys.lastHintDate)
            }
        } else {
            // First time, initialize
            defaults.set(today, forKey: Keys.lastHintDate)
        }
    }

    /// Uses a hint if available. Returns true if successful.
    @discardableResult
    func useHint() -> Bool {
        guard canUseHint else { return false }

        hintsUsedToday += 1
        defaults.set(hintsUsedToday, forKey: Keys.hintsUsedToday)
        defaults.set(Date(), forKey: Keys.lastHintDate)

        return true
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

        // Save Ball Sort levels
        if let encoded = try? JSONEncoder().encode(ballSortLevels) {
            defaults.set(encoded, forKey: Keys.ballSortLevels)
        }

        // Save Binary Grid levels
        if let encoded = try? JSONEncoder().encode(binaryGridLevels) {
            defaults.set(encoded, forKey: Keys.binaryGridLevels)
        }

        // Sync to widget
        syncToWidget()
    }

    /// Syncs data to the shared App Group for widget access
    private func syncToWidget() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.codebreaker.shared") else { return }

        sharedDefaults.set(currentStreak, forKey: "currentStreak")
        sharedDefaults.set(totalStars, forKey: "totalStars")

        // Save last daily challenge completion date
        if let latestDaily = completedDailyChallenges.last(where: { $0.completed }) {
            sharedDefaults.set(latestDaily.date, forKey: "lastDailyChallengeDate")
        }

        // Trigger widget refresh
        WidgetCenter.shared.reloadAllTimelines()
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

        // Load Ball Sort levels
        if let data = defaults.data(forKey: Keys.ballSortLevels),
           let decoded = try? JSONDecoder().decode([BallSortLevel].self, from: data) {
            ballSortLevels = decoded
        }

        // Load Binary Grid levels
        if let data = defaults.data(forKey: Keys.binaryGridLevels),
           let decoded = try? JSONDecoder().decode([BinaryGridLevel].self, from: data) {
            binaryGridLevels = decoded
        }

        // Load hints
        hintsUsedToday = defaults.integer(forKey: Keys.hintsUsedToday)
    }
    
    // MARK: - Debug/Reset

    func resetAllProgress() {
        levels = []
        currentStreak = 0
        longestStreak = 0
        totalStars = 0
        levelsCompleted = 0
        completedDailyChallenges = []

        // Reset Ball Sort
        ballSortLevels = []
        ballSortTotalStars = 0
        ballSortLevelsCompleted = 0

        // Reset Binary Grid
        binaryGridLevels = []
        binaryGridTotalStars = 0
        binaryGridLevelsCompleted = 0

        // Reset hints
        hintsUsedToday = 0

        defaults.removeObject(forKey: Keys.levels)
        defaults.removeObject(forKey: Keys.currentStreak)
        defaults.removeObject(forKey: Keys.longestStreak)
        defaults.removeObject(forKey: Keys.lastPlayedDate)
        defaults.removeObject(forKey: Keys.dailyChallenges)
        defaults.removeObject(forKey: Keys.ballSortLevels)
        defaults.removeObject(forKey: Keys.binaryGridLevels)
        defaults.removeObject(forKey: Keys.hintsUsedToday)
        defaults.removeObject(forKey: Keys.lastHintDate)

        generateLevels()
        generateBallSortLevels()
        generateBinaryGridLevels()
        checkDailyChallenge()
    }
}
