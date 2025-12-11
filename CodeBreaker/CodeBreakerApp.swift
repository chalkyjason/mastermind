import SwiftUI

@main
struct CodeBreakerApp: App {
    @StateObject private var gameManager = GameManager()
    @StateObject private var gameCenterManager = GameCenterManager()
    @StateObject private var livesManager = LivesManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameManager)
                .environmentObject(gameCenterManager)
                .environmentObject(livesManager)
                .onAppear {
                    gameCenterManager.authenticatePlayer()
                }
        }
    }
}
