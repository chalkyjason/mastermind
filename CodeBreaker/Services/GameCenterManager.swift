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
    
    init() {
        // Start authentication immediately
        authenticatePlayer()
    }
    
    // MARK: - Authentication
    
    func authenticatePlayer() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            DispatchQueue.main.async {
                if let vc = viewController {
                    // Present the Game Center login view controller
                    // Wait a bit to ensure window hierarchy is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            // Find the topmost view controller
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
                    } else {
                        print("⚠️ Game Center: Not authenticated (user may have disabled it)")
                    }
                    #endif
                }
            }
        }
    }
    
    // MARK: - Leaderboards
    
    func reportScore(_ score: Int, to leaderboard: LeaderboardID) {
        guard isAuthenticated else {
            #if DEBUG
            print("⚠️ Cannot report score: Not authenticated")
            #endif
            return
        }
        
        Task {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [leaderboard.rawValue]
                )
                #if DEBUG
                print("✅ Score \(score) submitted to \(leaderboard.rawValue)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Error submitting score to \(leaderboard.rawValue): \(error.localizedDescription)")
                #endif
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

    func reportBallSortCompletion(levelId: Int, stars: Int) {
        // Report Ball Sort level completion
        // Could have a separate leaderboard for Ball Sort if desired
        #if DEBUG
        print("Ball Sort level \(levelId) completed with \(stars) stars")
        #endif
    }

    func reportBinaryGridCompletion(levelId: Int, stars: Int) {
        // Report Binary Grid level completion
        #if DEBUG
        print("Binary Grid level \(levelId) completed with \(stars) stars")
        #endif
    }

    func reportFlowConnectCompletion(levelId: Int, stars: Int) {
        // Report Flow Connect level completion
        #if DEBUG
        print("Flow Connect level \(levelId) completed with \(stars) stars")
        #endif
    }

    // MARK: - Achievements
    
    func unlockAchievement(_ achievement: AchievementID, percentComplete: Double = 100.0) {
        guard isAuthenticated else {
            #if DEBUG
            print("⚠️ Cannot unlock achievement: Not authenticated")
            #endif
            return
        }
        
        let gkAchievement = GKAchievement(identifier: achievement.rawValue)
        gkAchievement.percentComplete = percentComplete
        gkAchievement.showsCompletionBanner = true
        
        Task {
            do {
                try await GKAchievement.report([gkAchievement])
                #if DEBUG
                print("✅ Achievement unlocked: \(achievement.rawValue) (\(percentComplete)%)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Error reporting achievement \(achievement.rawValue): \(error.localizedDescription)")
                #endif
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
            #if DEBUG
            print("⚠️ Cannot show leaderboards: Not authenticated. Attempting re-authentication...")
            #endif
            authenticatePlayer()
            return
        }
        
        let gcVC = GKGameCenterViewController(state: .leaderboards)
        gcVC.gameCenterDelegate = GameCenterDelegate.shared
        
        presentViewController(gcVC)
    }
    
    func showAchievements() {
        guard isAuthenticated else {
            #if DEBUG
            print("⚠️ Cannot show achievements: Not authenticated. Attempting re-authentication...")
            #endif
            authenticatePlayer()
            return
        }
        
        let gcVC = GKGameCenterViewController(state: .achievements)
        gcVC.gameCenterDelegate = GameCenterDelegate.shared
        
        presentViewController(gcVC)
    }
    
    private func presentViewController(_ viewController: UIViewController) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            // Find the topmost view controller
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
        info += "Local Player Available: \(GKLocalPlayer.local.isAuthenticated)\n"
        if let player = localPlayer {
            info += "Player Name: \(player.displayName)\n"
            info += "Player ID: \(player.gamePlayerID)\n"
            info += "Team Player ID: \(player.teamPlayerID)\n"
        }
        if let error = authenticationError {
            info += "Error: \(error)\n"
        }
        info += "Game Center Enabled: \(isGameCenterEnabled)\n"
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
