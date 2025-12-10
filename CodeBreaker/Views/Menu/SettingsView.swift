import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var gameCenterManager: GameCenterManager
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("colorblindMode") private var colorblindMode = false
    
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundTop")
                    .ignoresSafeArea()
                
                List {
                    // Game Settings
                    Section {
                        Toggle(isOn: $hapticsEnabled) {
                            Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                        }
                        .onChange(of: hapticsEnabled) { _, newValue in
                            HapticManager.setEnabled(newValue)
                            if newValue {
                                HapticManager.shared.impact(.medium)
                            }
                        }
                        
                        Toggle(isOn: $soundEnabled) {
                            Label("Sound Effects", systemImage: "speaker.wave.2")
                        }
                        
                        Toggle(isOn: $colorblindMode) {
                            Label("Colorblind Mode", systemImage: "eye")
                        }
                    } header: {
                        Text("Game Settings")
                    }
                    
                    // Game Center
                    Section {
                        Button(action: {
                            gameCenterManager.showLeaderboards()
                        }) {
                            Label("Leaderboards", systemImage: "list.number")
                        }
                        
                        Button(action: {
                            gameCenterManager.showAchievements()
                        }) {
                            Label("Achievements", systemImage: "trophy")
                        }
                        
                        HStack {
                            Label("Status", systemImage: "gamecontroller")
                            Spacer()
                            Text(gameCenterManager.isAuthenticated ? "Connected" : "Not Connected")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Game Center")
                    }
                    
                    // Stats
                    Section {
                        HStack {
                            Label("Total Stars", systemImage: "star.fill")
                            Spacer()
                            Text("\(gameManager.totalStars)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("Levels Completed", systemImage: "checkmark.circle")
                            Spacer()
                            Text("\(gameManager.levelsCompleted)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("Current Streak", systemImage: "flame")
                            Spacer()
                            Text("\(gameManager.currentStreak) days")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("Longest Streak", systemImage: "flame.fill")
                            Spacer()
                            Text("\(gameManager.longestStreak) days")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Statistics")
                    }
                    
                    // About
                    Section {
                        HStack {
                            Label("Version", systemImage: "info.circle")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                        
                        Link(destination: URL(string: "https://example.com/privacy")!) {
                            Label("Privacy Policy", systemImage: "hand.raised")
                        }
                        
                        Link(destination: URL(string: "https://example.com/terms")!) {
                            Label("Terms of Service", systemImage: "doc.text")
                        }
                    } header: {
                        Text("About")
                    }
                    
                    // Danger Zone
                    Section {
                        Button(role: .destructive, action: {
                            showingResetAlert = true
                        }) {
                            Label("Reset All Progress", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    } header: {
                        Text("Data")
                    } footer: {
                        Text("This will permanently delete all your progress, including completed levels and achievements.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Reset Progress?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    gameManager.resetAllProgress()
                    HapticManager.shared.notification(.warning)
                }
            } message: {
                Text("This will delete all your progress. This action cannot be undone.")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(GameManager())
        .environmentObject(GameCenterManager())
}
