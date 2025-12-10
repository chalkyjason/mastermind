import SwiftUI

@main
struct CodeBreakerApp: App {
    @StateObject private var gameManager = GameManager()
    @StateObject private var gameCenterManager = GameCenterManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameManager)
                .environmentObject(gameCenterManager)
                .onAppear {
                    gameCenterManager.authenticatePlayer()
                }
        }
    }
}
