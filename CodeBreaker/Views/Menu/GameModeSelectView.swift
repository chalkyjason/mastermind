import SwiftUI

struct GameModeSelectView: View {
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingCodeBreaker = false
    @State private var showingBallSort = false
    @State private var showingBinaryGrid = false
    @State private var showingFlowConnect = false
    @State private var showingDailyChallenge = false
    @State private var showingTimeAttack = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color("BackgroundTop"), Color("BackgroundBottom")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("Select Game")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)

                    Spacer()

                    // Spacer for balance
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding()

                ScrollView {
                    VStack(spacing: 16) {
                        // Main Games Section
                        SectionHeader(title: "Puzzle Games", icon: "puzzlepiece.fill")

                        GameModeCard(
                            title: "Code Breaker",
                            subtitle: "Crack the secret code",
                            icon: "lock.circle.fill",
                            color: Color("AccentGreen"),
                            stats: "\(gameManager.levelsCompleted) levels · \(gameManager.totalStars) ⭐"
                        ) {
                            SoundManager.shared.buttonTap()
                            showingCodeBreaker = true
                        }

                        GameModeCard(
                            title: "Ball Sort",
                            subtitle: "Sort balls by color",
                            icon: "testtube.2",
                            color: Color("AccentBlue"),
                            stats: "\(gameManager.ballSortLevelsCompleted) levels · \(gameManager.ballSortTotalStars) ⭐"
                        ) {
                            SoundManager.shared.buttonTap()
                            showingBallSort = true
                        }

                        GameModeCard(
                            title: "Binary Grid",
                            subtitle: "Fill the grid with logic",
                            icon: "square.grid.3x3.fill",
                            color: Color("AccentPurple"),
                            stats: "\(gameManager.binaryGridLevelsCompleted) levels · \(gameManager.binaryGridTotalStars) ⭐"
                        ) {
                            SoundManager.shared.buttonTap()
                            showingBinaryGrid = true
                        }

                        GameModeCard(
                            title: "Flow Connect",
                            subtitle: "Connect matching colors",
                            icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                            color: Color("AccentOrange"),
                            stats: "\(gameManager.flowConnectLevelsCompleted) levels · \(gameManager.flowConnectTotalStars) ⭐"
                        ) {
                            SoundManager.shared.buttonTap()
                            showingFlowConnect = true
                        }

                        // Challenge Modes Section
                        SectionHeader(title: "Challenges", icon: "flame.fill")
                            .padding(.top, 8)

                        GameModeCard(
                            title: "Daily Challenge",
                            subtitle: "New puzzle every day",
                            icon: "calendar.badge.clock",
                            color: Color("PegPink"),
                            badge: gameManager.hasDailyChallengeAvailable ? "NEW" : nil,
                            stats: "\(gameManager.currentStreak) day streak"
                        ) {
                            SoundManager.shared.buttonTap()
                            showingDailyChallenge = true
                        }

                        GameModeCard(
                            title: "Time Attack",
                            subtitle: "Race against the clock",
                            icon: "timer",
                            color: Color("AccentOrange"),
                            stats: "90 seconds per round"
                        ) {
                            SoundManager.shared.buttonTap()
                            showingTimeAttack = true
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showingCodeBreaker) {
            LevelSelectView()
        }
        .navigationDestination(isPresented: $showingBallSort) {
            BallSortLevelSelectView()
        }
        .navigationDestination(isPresented: $showingBinaryGrid) {
            BinaryGridLevelSelectView()
        }
        .navigationDestination(isPresented: $showingFlowConnect) {
            FlowConnectLevelSelectView()
        }
        .navigationDestination(isPresented: $showingDailyChallenge) {
            DailyChallengeView()
        }
        .navigationDestination(isPresented: $showingTimeAttack) {
            TimeAttackView(tier: .beginner)
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
}

// MARK: - Game Mode Card

struct GameModeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var badge: String? = nil
    var stats: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            action()
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(color)
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.title)
                        .foregroundColor(.white)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)

                        if let badge = badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))

                    if let stats = stats {
                        Text(stats)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(CardButtonStyle())
    }
}

// MARK: - Card Button Style

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        GameModeSelectView()
            .environmentObject(GameManager())
    }
}
