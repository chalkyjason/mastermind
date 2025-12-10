import SwiftUI

struct DailyChallengeView: View {
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingGame = false
    
    var challenge: DailyChallenge? {
        gameManager.dailyChallenge
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color("BackgroundTop"), Color("BackgroundBottom")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
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
                    
                    Text("Daily Challenge")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding()
                
                Spacer()
                
                // Challenge card
                VStack(spacing: 20) {
                    // Calendar icon
                    ZStack {
                        Circle()
                            .fill(Color("AccentPurple").opacity(0.3))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 44))
                            .foregroundColor(Color("AccentPurple"))
                    }
                    
                    // Date
                    Text(challenge?.dateString ?? "Today")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                    
                    // Difficulty info
                    if let challenge = challenge {
                        VStack(spacing: 8) {
                            Text(challenge.tier.name)
                                .font(.headline)
                                .foregroundColor(challenge.tier.color)
                            
                            Text("\(challenge.tier.codeLength) pegs • \(challenge.tier.colorCount) colors • \(challenge.tier.maxAttempts) attempts")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    
                    // Status
                    if challenge?.completed == true {
                        // Already completed
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Completed!")
                                    .foregroundColor(.green)
                            }
                            .font(.headline)
                            
                            if let stars = challenge?.stars {
                                HStack(spacing: 8) {
                                    ForEach(0..<3, id: \.self) { index in
                                        Image(systemName: index < stars ? "star.fill" : "star")
                                            .font(.title2)
                                            .foregroundColor(index < stars ? Color("AccentYellow") : .gray)
                                    }
                                }
                            }
                            
                            if let attempts = challenge?.attempts {
                                Text("Solved in \(attempts) attempt\(attempts == 1 ? "" : "s")")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Text("Come back tomorrow for a new challenge!")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        }
                    } else {
                        // Play button
                        Button(action: { showingGame = true }) {
                            Label("Play Challenge", systemImage: "play.fill")
                                .font(.headline.weight(.bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Color("AccentPurple"))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .padding(.horizontal, 32)
                    }
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                )
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Stats
                DailyChallengeStatsView()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showingGame) {
            if let challenge = challenge {
                GameView(
                    tier: challenge.tier,
                    customCode: challenge.secretCode,
                    isDaily: true
                )
            }
        }
    }
}

// MARK: - Stats View

struct DailyChallengeStatsView: View {
    @EnvironmentObject var gameManager: GameManager
    
    var completedCount: Int {
        gameManager.completedDailyChallenges.count
    }
    
    var totalStars: Int {
        gameManager.completedDailyChallenges.compactMap { $0.stars }.reduce(0, +)
    }
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("\(completedCount)")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Text("Completed")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.3))
            
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(Color("AccentYellow"))
                    Text("\(totalStars)")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                }
                Text("Total Stars")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.3))
            
            VStack(spacing: 4) {
                Text("\(gameManager.currentStreak)")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Text("Streak")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        DailyChallengeView()
            .environmentObject(GameManager())
    }
}
