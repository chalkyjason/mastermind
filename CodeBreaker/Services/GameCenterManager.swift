import GameKit
import SwiftUI

// MARK: - Game Center Manager

class GameCenterManager: ObservableObject {
    static let shared = GameCenterManager()

    @Published var isAuthenticated = false
    @Published var localPlayer: GKLocalPlayer?
    @Published var showingGameCenter = false
    @Published var authenticationError: String?

    var isGameCenterEnabled: Bool {
        return GKLocalPlayer.local.isAuthenticated
    }

    // MARK: - Leaderboard IDs
    // Configure these in App Store Connect

    enum LeaderboardID: String, CaseIterable {
        // Overall
        case totalStars = "com.puzzlemaster.totalstars"
        case longestStreak = "com.puzzlemaster.longeststreak"

        // Code Breaker
        case codeBreakerStars = "com.puzzlemaster.codebreaker.stars"
        case codeBreakerLevels = "com.puzzlemaster.codebreaker.levels"

        // Ball Sort
        case ballSortStars = "com.puzzlemaster.ballsort.stars"
        case ballSortLevels = "com.puzzlemaster.ballsort.levels"

        // Binary Grid
        case binaryGridStars = "com.puzzlemaster.binarygrid.stars"
        case binaryGridLevels = "com.puzzlemaster.binarygrid.levels"

        // Flow Connect
        case flowConnectStars = "com.puzzlemaster.flowconnect.stars"
        case flowConnectLevels = "com.puzzlemaster.flowconnect.levels"

        var displayName: String {
            switch self {
            case .totalStars: return "Total Stars"
            case .longestStreak: return "Longest Streak"
            case .codeBreakerStars: return "Code Breaker Stars"
            case .codeBreakerLevels: return "Code Breaker Levels"
            case .ballSortStars: return "Ball Sort Stars"
            case .ballSortLevels: return "Ball Sort Levels"
            case .binaryGridStars: return "Binary Grid Stars"
            case .binaryGridLevels: return "Binary Grid Levels"
            case .flowConnectStars: return "Flow Connect Stars"
            case .flowConnectLevels: return "Flow Connect Levels"
            }
        }
    }

    // MARK: - Achievement IDs
    // Configure these in App Store Connect

    enum AchievementID: String, CaseIterable {
        // Getting Started
        case firstWin = "com.puzzlemaster.firstwin"
        case tryAllGames = "com.puzzlemaster.tryallgames"

        // Code Breaker Progression
        case cbCompleteTutorial = "com.puzzlemaster.cb.tutorial"
        case cbCompleteBeginner = "com.puzzlemaster.cb.beginner"
        case cbCompleteIntermediate = "com.puzzlemaster.cb.intermediate"
        case cbCompleteAdvanced = "com.puzzlemaster.cb.advanced"
        case cbCompleteExpert = "com.puzzlemaster.cb.expert"
        case cbCompleteMaster = "com.puzzlemaster.cb.master"

        // Ball Sort Progression
        case bsComplete10 = "com.puzzlemaster.bs.level10"
        case bsComplete50 = "com.puzzlemaster.bs.level50"
        case bsComplete100 = "com.puzzlemaster.bs.level100"

        // Binary Grid Progression
        case bgComplete10 = "com.puzzlemaster.bg.level10"
        case bgComplete50 = "com.puzzlemaster.bg.level50"
        case bgComplete100 = "com.puzzlemaster.bg.level100"

        // Flow Connect Progression
        case fcComplete10 = "com.puzzlemaster.fc.level10"
        case fcComplete50 = "com.puzzlemaster.fc.level50"
        case fcComplete100 = "com.puzzlemaster.fc.level100"

        // Star Milestones (combined across all games)
        case stars50 = "com.puzzlemaster.stars50"
        case stars100 = "com.puzzlemaster.stars100"
        case stars250 = "com.puzzlemaster.stars250"
        case stars500 = "com.puzzlemaster.stars500"
        case stars1000 = "com.puzzlemaster.stars1000"

        // Streak Achievements
        case streak3 = "com.puzzlemaster.streak3"
        case streak7 = "com.puzzlemaster.streak7"
        case streak14 = "com.puzzlemaster.streak14"
        case streak30 = "com.puzzlemaster.streak30"
        case streak100 = "com.puzzlemaster.streak100"

        // Perfect Performance
        case perfectCodeBreaker = "com.puzzlemaster.cb.perfect"     // 3 stars on first try
        case perfectBallSort = "com.puzzlemaster.bs.perfect"        // Minimum moves
        case perfectBinaryGrid = "com.puzzlemaster.bg.perfect"      // Under 30 seconds
        case perfectFlowConnect = "com.puzzlemaster.fc.perfect"     // First try connection

        // Dedication
        case dailyPlayer = "com.puzzlemaster.daily7"                // Play 7 days in a row
        case weekendWarrior = "com.puzzlemaster.weekend"            // Play on Saturday and Sunday
        case puzzleMaster = "com.puzzlemaster.master"               // Complete 100 levels in any game

        var displayName: String {
            switch self {
            case .firstWin: return "First Win"
            case .tryAllGames: return "Explorer"
            case .cbCompleteTutorial: return "Code Breaker Tutorial"
            case .cbCompleteBeginner: return "Code Breaker Beginner"
            case .cbCompleteIntermediate: return "Code Breaker Intermediate"
            case .cbCompleteAdvanced: return "Code Breaker Advanced"
            case .cbCompleteExpert: return "Code Breaker Expert"
            case .cbCompleteMaster: return "Code Breaker Master"
            case .bsComplete10: return "Ball Sort Apprentice"
            case .bsComplete50: return "Ball Sort Pro"
            case .bsComplete100: return "Ball Sort Expert"
            case .bgComplete10: return "Binary Beginner"
            case .bgComplete50: return "Binary Pro"
            case .bgComplete100: return "Binary Expert"
            case .fcComplete10: return "Flow Starter"
            case .fcComplete50: return "Flow Pro"
            case .fcComplete100: return "Flow Master"
            case .stars50: return "50 Stars"
            case .stars100: return "100 Stars"
            case .stars250: return "250 Stars"
            case .stars500: return "500 Stars"
            case .stars1000: return "1000 Stars"
            case .streak3: return "3 Day Streak"
            case .streak7: return "Week Streak"
            case .streak14: return "Two Week Streak"
            case .streak30: return "Month Streak"
            case .streak100: return "100 Day Streak"
            case .perfectCodeBreaker: return "Perfect Code"
            case .perfectBallSort: return "Efficient Sorter"
            case .perfectBinaryGrid: return "Speed Binary"
            case .perfectFlowConnect: return "Perfect Flow"
            case .dailyPlayer: return "Daily Player"
            case .weekendWarrior: return "Weekend Warrior"
            case .puzzleMaster: return "Puzzle Master"
            }
        }
    }

    init() {
        authenticatePlayer()
    }

    // MARK: - Authentication

    func authenticatePlayer() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            DispatchQueue.main.async {
                if let vc = viewController {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            var topVC = rootVC
                            while let presented = topVC.presentedViewController {
                                topVC = presented
                            }
                            topVC.present(vc, animated: true)
                        }
                    }
                } else if GKLocalPlayer.local.isAuthenticated {
                    self?.isAuthenticated = true
                    self?.localPlayer = GKLocalPlayer.local
                    self?.authenticationError = nil
                    #if DEBUG
                    print("✅ Game Center: Authenticated as \(GKLocalPlayer.local.displayName)")
                    #endif
                } else {
                    self?.isAuthenticated = false
                    self?.authenticationError = error?.localizedDescription ?? "Game Center not available"
                    #if DEBUG
                    if let error = error {
                        print("❌ Game Center authentication error: \(error.localizedDescription)")
                    }
                    #endif
                }
            }
        }
    }

    // MARK: - Leaderboard Reporting

    func reportScore(_ score: Int, to leaderboard: LeaderboardID) {
        guard isAuthenticated else { return }

        Task {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [leaderboard.rawValue]
                )
                #if DEBUG
                print("✅ Score \(score) submitted to \(leaderboard.displayName)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Error submitting score: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - Game-Specific Reporting

    func reportCodeBreakerStats(totalStars: Int, levelsCompleted: Int) {
        reportScore(totalStars, to: .codeBreakerStars)
        reportScore(levelsCompleted, to: .codeBreakerLevels)
    }

    func reportBallSortStats(totalStars: Int, levelsCompleted: Int) {
        reportScore(totalStars, to: .ballSortStars)
        reportScore(levelsCompleted, to: .ballSortLevels)

        // Check level achievements
        if levelsCompleted >= 10 { unlockAchievement(.bsComplete10) }
        if levelsCompleted >= 50 { unlockAchievement(.bsComplete50) }
        if levelsCompleted >= 100 { unlockAchievement(.bsComplete100) }
    }

    func reportBinaryGridStats(totalStars: Int, levelsCompleted: Int) {
        reportScore(totalStars, to: .binaryGridStars)
        reportScore(levelsCompleted, to: .binaryGridLevels)

        // Check level achievements
        if levelsCompleted >= 10 { unlockAchievement(.bgComplete10) }
        if levelsCompleted >= 50 { unlockAchievement(.bgComplete50) }
        if levelsCompleted >= 100 { unlockAchievement(.bgComplete100) }
    }

    func reportFlowConnectStats(totalStars: Int, levelsCompleted: Int) {
        reportScore(totalStars, to: .flowConnectStars)
        reportScore(levelsCompleted, to: .flowConnectLevels)

        // Check level achievements
        if levelsCompleted >= 10 { unlockAchievement(.fcComplete10) }
        if levelsCompleted >= 50 { unlockAchievement(.fcComplete50) }
        if levelsCompleted >= 100 { unlockAchievement(.fcComplete100) }
    }

    func reportOverallStats(totalStars: Int, longestStreak: Int) {
        reportScore(totalStars, to: .totalStars)
        reportScore(longestStreak, to: .longestStreak)

        // Check star achievements
        if totalStars >= 50 { unlockAchievement(.stars50) }
        if totalStars >= 100 { unlockAchievement(.stars100) }
        if totalStars >= 250 { unlockAchievement(.stars250) }
        if totalStars >= 500 { unlockAchievement(.stars500) }
        if totalStars >= 1000 { unlockAchievement(.stars1000) }
    }

    // Legacy methods for backward compatibility
    func reportLevelCompletion(levelId: Int, stars: Int) {
        if stars == 3 {
            unlockAchievement(.perfectCodeBreaker)
        }
    }

    func reportBallSortCompletion(levelId: Int, stars: Int) {
        if stars == 3 {
            unlockAchievement(.perfectBallSort)
        }
    }

    func reportBinaryGridCompletion(levelId: Int, stars: Int) {
        if stars == 3 {
            unlockAchievement(.perfectBinaryGrid)
        }
    }

    func reportFlowConnectCompletion(levelId: Int, stars: Int) {
        if stars == 3 {
            unlockAchievement(.perfectFlowConnect)
        }
    }

    func reportStreak(_ streak: Int) {
        reportScore(streak, to: .longestStreak)

        // Check streak achievements
        if streak >= 3 { unlockAchievement(.streak3) }
        if streak >= 7 { unlockAchievement(.streak7) }
        if streak >= 14 { unlockAchievement(.streak14) }
        if streak >= 30 { unlockAchievement(.streak30) }
        if streak >= 100 { unlockAchievement(.streak100) }
    }

    func reportDailyChallengeCompletion(stars: Int) {
        // Track daily challenge completions
    }

    func reportFirstWin() {
        unlockAchievement(.firstWin)
    }

    func reportTierCompletion(_ tier: DifficultyTier) {
        switch tier {
        case .tutorial: unlockAchievement(.cbCompleteTutorial)
        case .beginner: unlockAchievement(.cbCompleteBeginner)
        case .intermediate: unlockAchievement(.cbCompleteIntermediate)
        case .advanced: unlockAchievement(.cbCompleteAdvanced)
        case .expert: unlockAchievement(.cbCompleteExpert)
        case .master: unlockAchievement(.cbCompleteMaster)
        }
    }

    // MARK: - Achievement Reporting

    func unlockAchievement(_ achievement: AchievementID, percentComplete: Double = 100.0) {
        guard isAuthenticated else { return }

        let gkAchievement = GKAchievement(identifier: achievement.rawValue)
        gkAchievement.percentComplete = percentComplete
        gkAchievement.showsCompletionBanner = true

        Task {
            do {
                try await GKAchievement.report([gkAchievement])
                #if DEBUG
                print("✅ Achievement unlocked: \(achievement.displayName)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Error reporting achievement: \(error.localizedDescription)")
                #endif
            }
        }
    }

    func reportStarMilestone(_ totalStars: Int) {
        reportOverallStats(totalStars: totalStars, longestStreak: 0)
    }

    func reportPerfectLevel() {
        unlockAchievement(.perfectCodeBreaker)
    }

    // MARK: - Show Game Center UI

    func showLeaderboards() {
        guard isAuthenticated else {
            authenticatePlayer()
            return
        }

        let gcVC = GKGameCenterViewController(state: .leaderboards)
        gcVC.gameCenterDelegate = GameCenterDelegate.shared
        presentViewController(gcVC)
    }

    func showLeaderboard(_ leaderboard: LeaderboardID) {
        guard isAuthenticated else {
            authenticatePlayer()
            return
        }

        let gcVC = GKGameCenterViewController(leaderboardID: leaderboard.rawValue, playerScope: .global, timeScope: .allTime)
        gcVC.gameCenterDelegate = GameCenterDelegate.shared
        presentViewController(gcVC)
    }

    func showAchievements() {
        guard isAuthenticated else {
            authenticatePlayer()
            return
        }

        let gcVC = GKGameCenterViewController(state: .achievements)
        gcVC.gameCenterDelegate = GameCenterDelegate.shared
        presentViewController(gcVC)
    }

    func showGameCenter() {
        guard isAuthenticated else {
            authenticatePlayer()
            return
        }

        let gcVC = GKGameCenterViewController(state: .default)
        gcVC.gameCenterDelegate = GameCenterDelegate.shared
        presentViewController(gcVC)
    }

    private func presentViewController(_ viewController: UIViewController) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(viewController, animated: true)
        }
    }

    // MARK: - Debug Helper

    func getDebugInfo() -> String {
        var info = "Game Center Debug Info:\n"
        info += "========================\n"
        info += "Authenticated: \(isAuthenticated)\n"
        if let player = localPlayer {
            info += "Player: \(player.displayName)\n"
        }
        if let error = authenticationError {
            info += "Error: \(error)\n"
        }
        return info
    }
}

// MARK: - Game Center Delegate

class GameCenterDelegate: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterDelegate()

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
