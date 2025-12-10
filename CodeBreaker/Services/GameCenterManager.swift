import GameKit
import SwiftUI

// MARK: - Game Center Manager

class GameCenterManager: ObservableObject {
    static let shared = GameCenterManager()
    
    @Published var isAuthenticated = false
    @Published var localPlayer: GKLocalPlayer?
    @Published var showingGameCenter = false
    
    // Leaderboard IDs - configure these in App Store Connect
    enum LeaderboardID: String {
        case totalStars = "com.codebreaker.totalstars"
        case longestStreak = "com.codebreaker.longeststreak"
        case dailyChallengeStreak = "com.codebreaker.dailystreak"
        case levelsCompleted = "com.codebreaker.levelscompleted"
    }
    
    // Achievement IDs - configure these in App Store Connect
    enum AchievementID: String {
        // Tutorial
        case firstWin = "com.codebreaker.firstwin"
        case completeTutorial = "com.codebreaker.tutorial"
        
        // Progression
        case beginner = "com.codebreaker.beginner"
        case intermediate = "com.codebreaker.intermediate"
        case advanced = "com.codebreaker.advanced"
        case expert = "com.codebreaker.expert"
        case master = "com.codebreaker.master"
        
        // Stars
        case stars50 = "com.codebreaker.stars50"
        case stars100 = "com.codebreaker.stars100"
        case stars250 = "com.codebreaker.stars250"
        case stars500 = "com.codebreaker.stars500"
        
        // Streak
        case streak7 = "com.codebreaker.streak7"
        case streak30 = "com.codebreaker.streak30"
        case streak100 = "com.codebreaker.streak100"
        
        // Special
        case perfectLevel = "com.codebreaker.perfect"
        case speedDemon = "com.codebreaker.speeddemon"
        case dailyDevotee = "com.codebreaker.dailydevotee"
    }
    
    init() {}
    
    // MARK: - Authentication
    
    func authenticatePlayer() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            if let vc = viewController {
                // Present the Game Center login view controller
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(vc, animated: true)
                }
            } else if GKLocalPlayer.local.isAuthenticated {
                self?.isAuthenticated = true
                self?.localPlayer = GKLocalPlayer.local
                print("Game Center: Authenticated as \(GKLocalPlayer.local.displayName)")
            } else {
                self?.isAuthenticated = false
                if let error = error {
                    print("Game Center authentication error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Leaderboards
    
    func reportScore(_ score: Int, to leaderboard: LeaderboardID) {
        guard isAuthenticated else { return }
        
        GKLeaderboard.submitScore(
            score,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [leaderboard.rawValue]
        ) { error in
            if let error = error {
                print("Error submitting score: \(error.localizedDescription)")
            } else {
                print("Score \(score) submitted to \(leaderboard.rawValue)")
            }
        }
    }
    
    func reportLevelCompletion(levelId: Int, stars: Int) {
        // Update total stars leaderboard
        // Note: In production, you'd track total stars in GameManager and report that
        reportScore(stars, to: .totalStars)
    }
    
    func reportStreak(_ streak: Int) {
        reportScore(streak, to: .longestStreak)
        
        // Check streak achievements
        if streak >= 7 {
            unlockAchievement(.streak7)
        }
        if streak >= 30 {
            unlockAchievement(.streak30)
        }
        if streak >= 100 {
            unlockAchievement(.streak100)
        }
    }
    
    func reportDailyChallengeCompletion(stars: Int) {
        // Could track a daily challenge completion streak here
    }
    
    // MARK: - Achievements
    
    func unlockAchievement(_ achievement: AchievementID, percentComplete: Double = 100.0) {
        guard isAuthenticated else { return }
        
        let gkAchievement = GKAchievement(identifier: achievement.rawValue)
        gkAchievement.percentComplete = percentComplete
        gkAchievement.showsCompletionBanner = true
        
        GKAchievement.report([gkAchievement]) { error in
            if let error = error {
                print("Error reporting achievement: \(error.localizedDescription)")
            } else {
                print("Achievement unlocked: \(achievement.rawValue)")
            }
        }
    }
    
    func reportFirstWin() {
        unlockAchievement(.firstWin)
    }
    
    func reportTierCompletion(_ tier: DifficultyTier) {
        switch tier {
        case .tutorial: unlockAchievement(.completeTutorial)
        case .beginner: unlockAchievement(.beginner)
        case .intermediate: unlockAchievement(.intermediate)
        case .advanced: unlockAchievement(.advanced)
        case .expert: unlockAchievement(.expert)
        case .master: unlockAchievement(.master)
        }
    }
    
    func reportStarMilestone(_ totalStars: Int) {
        if totalStars >= 50 { unlockAchievement(.stars50) }
        if totalStars >= 100 { unlockAchievement(.stars100) }
        if totalStars >= 250 { unlockAchievement(.stars250) }
        if totalStars >= 500 { unlockAchievement(.stars500) }
        
        // Also update leaderboard
        reportScore(totalStars, to: .totalStars)
    }
    
    func reportPerfectLevel() {
        unlockAchievement(.perfectLevel)
    }
    
    // MARK: - Show Game Center UI
    
    func showLeaderboards() {
        guard isAuthenticated else {
            authenticatePlayer()
            return
        }
        
        let gcVC = GKGameCenterViewController(state: .leaderboards)
        gcVC.gameCenterDelegate = GameCenterDelegate.shared
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(gcVC, animated: true)
        }
    }
    
    func showAchievements() {
        guard isAuthenticated else {
            authenticatePlayer()
            return
        }
        
        let gcVC = GKGameCenterViewController(state: .achievements)
        gcVC.gameCenterDelegate = GameCenterDelegate.shared
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(gcVC, animated: true)
        }
    }
}

// MARK: - Game Center Delegate

class GameCenterDelegate: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterDelegate()
    
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
