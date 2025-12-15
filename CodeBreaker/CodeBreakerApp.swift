import SwiftUI

@main
struct CodeBreakerApp: App {
    @StateObject private var gameManager = GameManager()
    @StateObject private var gameCenterManager = GameCenterManager()
    @StateObject private var livesManager = LivesManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Initialize Google Mobile Ads SDK
        AdManager.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameManager)
                .environmentObject(gameCenterManager)
                .environmentObject(livesManager)
                .onAppear {
                    gameCenterManager.authenticatePlayer()
                    // Request notification permissions on first launch
                    notificationManager.requestAuthorization()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                notificationManager.appDidBecomeActive()
                livesManager.appDidBecomeActive()
            case .background:
                notificationManager.appDidEnterBackground()
                livesManager.appDidEnterBackground()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
