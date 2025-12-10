import SwiftUI

struct ContentView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var showingGame = false
    @State private var showingLevelSelect = false
    @State private var showingDailyChallenge = false
    @State private var showingSettings = false
    @State private var showingHowToPlay = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color("BackgroundTop"), Color("BackgroundBottom")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Logo/Title
                    VStack(spacing: 8) {
                        Text("CODE")
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Text("BREAKER")
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color("AccentYellow"), Color("AccentOrange")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                    
                    // Code preview animation
                    CodePreviewView()
                        .frame(height: 60)
                        .padding(.vertical, 20)
                    
                    Spacer()
                    
                    // Menu buttons
                    VStack(spacing: 16) {
                        MenuButton(
                            title: "Play",
                            icon: "play.fill",
                            color: Color("AccentGreen")
                        ) {
                            showingLevelSelect = true
                        }
                        
                        MenuButton(
                            title: "Daily Challenge",
                            icon: "calendar.badge.clock",
                            color: Color("AccentPurple"),
                            badge: gameManager.hasDailyChallengeAvailable ? "NEW" : nil
                        ) {
                            showingDailyChallenge = true
                        }
                        
                        HStack(spacing: 16) {
                            SmallMenuButton(
                                title: "How to Play",
                                icon: "questionmark.circle.fill",
                                color: Color("AccentBlue")
                            ) {
                                showingHowToPlay = true
                            }
                            
                            SmallMenuButton(
                                title: "Settings",
                                icon: "gearshape.fill",
                                color: Color("AccentGray")
                            ) {
                                showingSettings = true
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Stats bar
                    StatsBarView()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                }
            }
            .navigationDestination(isPresented: $showingLevelSelect) {
                LevelSelectView()
            }
            .navigationDestination(isPresented: $showingDailyChallenge) {
                DailyChallengeView()
            }
            .sheet(isPresented: $showingHowToPlay) {
                HowToPlayView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

// MARK: - Menu Button Components

struct MenuButton: View {
    let title: String
    let icon: String
    let color: Color
    var badge: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            action()
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.title3.weight(.semibold))
                Spacer()
                if let badge = badge {
                    Text(badge)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: color.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct SmallMenuButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: color.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Code Preview Animation

struct CodePreviewView: View {
    @State private var animatedColors: [PegColor] = [.red, .blue, .green, .yellow]
    
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(animatedColors[index].color)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 3)
                    )
                    .shadow(color: animatedColors[index].color.opacity(0.5), radius: 8, y: 2)
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedColors = PegColor.allCases.shuffled().prefix(4).map { $0 }
            }
        }
    }
}

// MARK: - Stats Bar

struct StatsBarView: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        HStack(spacing: 20) {
            StatItem(icon: "star.fill", value: "\(gameManager.totalStars)", label: "Stars")
            StatItem(icon: "checkmark.circle.fill", value: "\(gameManager.levelsCompleted)", label: "Levels")
            StatItem(icon: "flame.fill", value: "\(gameManager.currentStreak)", label: "Streak")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(Color("AccentYellow"))
                Text(value)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(GameManager())
        .environmentObject(GameCenterManager())
}
