import SwiftUI

@main
struct CodeBreakerApp: App {
    @StateObject private var gameManager = GameManager()
    @StateObject private var gameCenterManager = GameCenterManager()
    // NOTE: If you see "Cannot find 'LivesManager' in scope", ensure that 'LivesManager.swift' is included in your target. No import is necessary if it is part of the same module.
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
