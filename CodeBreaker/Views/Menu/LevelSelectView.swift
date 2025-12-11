import SwiftUI

struct LevelSelectView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var livesManager: LivesManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTier: DifficultyTier = .tutorial
    @State private var showingNoLivesAlert = false

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
                    Button(action: {
                        HapticManager.shared.navigate()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Select Level")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Placeholder for balance
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding()
                
                // Tier selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(DifficultyTier.allCases, id: \.self) { tier in
                            TierTabButton(
                                tier: tier,
                                isSelected: selectedTier == tier,
                                isUnlocked: gameManager.isTierUnlocked(tier),
                                progress: gameManager.tierProgress(tier)
                            ) {
                                if gameManager.isTierUnlocked(tier) {
                                    withAnimation {
                                        selectedTier = tier
                                    }
                                    HapticManager.shared.selection()
                                } else {
                                    HapticManager.shared.lockedItemTap()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Tier info
                TierInfoBar(tier: selectedTier, progress: gameManager.tierProgress(selectedTier))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                // No lives banner
                if !livesManager.hasLives {
                    NoLivesBanner(livesManager: livesManager)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                // Levels grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(gameManager.levels(for: selectedTier)) { level in
                            if level.isUnlocked {
                                if livesManager.hasLives {
                                    NavigationLink(destination: GameView(tier: level.tier, level: level)) {
                                        LevelCell(level: level)
                                    }
                                    .simultaneousGesture(TapGesture().onEnded {
                                        HapticManager.shared.primaryButtonTap()
                                    })
                                } else {
                                    LevelCell(level: level)
                                        .onTapGesture {
                                            showingNoLivesAlert = true
                                            HapticManager.shared.notification(.warning)
                                        }
                                }
                            } else {
                                LevelCell(level: level)
                                    .onTapGesture {
                                        HapticManager.shared.lockedItemTap()
                                    }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .alert("No Lives", isPresented: $showingNoLivesAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let timeString = livesManager.formattedTimeUntilNextLife {
                Text("You're out of lives! Next life in \(timeString). Watch an ad or wait for lives to regenerate.")
            } else {
                Text("You're out of lives! Watch an ad or wait for lives to regenerate.")
            }
        }
    }
}

// MARK: - No Lives Banner

struct NoLivesBanner: View {
    @ObservedObject var livesManager: LivesManager
    @State private var isLoadingAd = false

    var body: some View {
        HStack {
            Image(systemName: "heart.slash.fill")
                .foregroundColor(Color("PegRed"))

            VStack(alignment: .leading, spacing: 2) {
                Text("No lives remaining")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                if let timeString = livesManager.formattedTimeUntilNextLife {
                    Text("Next life in \(timeString)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            if livesManager.isAdAvailable {
                Button(action: watchAd) {
                    HStack(spacing: 4) {
                        if isLoadingAd {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "play.rectangle.fill")
                                .font(.caption)
                        }
                        Text("Get Life")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color("AccentPurple"))
                    .clipShape(Capsule())
                }
                .disabled(isLoadingAd)
            }
        }
        .padding()
        .background(Color("PegRed").opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func watchAd() {
        isLoadingAd = true
        livesManager.requestAdForLife { success in
            isLoadingAd = false
            if !success {
                HapticManager.shared.notification(.error)
            }
        }
    }
}

// MARK: - Tier Tab Button

struct TierTabButton: View {
    let tier: DifficultyTier
    let isSelected: Bool
    let isUnlocked: Bool
    let progress: (completed: Int, total: Int, stars: Int, maxStars: Int)
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? tier.color : Color.white.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    if isUnlocked {
                        Image(systemName: tier.iconName)
                            .font(.title3)
                            .foregroundColor(isSelected ? .white : tier.color)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
                
                Text(tier.name)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                
                // Progress indicator
                if isUnlocked && progress.completed > 0 {
                    Text("\(progress.completed)/\(progress.total)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .opacity(isUnlocked ? 1 : 0.5)
    }
}

// MARK: - Tier Info Bar

struct TierInfoBar: View {
    let tier: DifficultyTier
    let progress: (completed: Int, total: Int, stars: Int, maxStars: Int)
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(tier.name)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                
                Text("\(tier.codeLength) pegs • \(tier.colorCount) colors • \(tier.maxAttempts) attempts")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Stars progress
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundColor(Color("AccentYellow"))
                Text("\(progress.stars)/\(progress.maxStars)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding()
        .background(tier.color.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Level Cell

struct LevelCell: View {
    let level: GameLevel
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(level.isUnlocked ? level.tier.color.opacity(0.3) : Color.gray.opacity(0.2))
                    .frame(height: 50)
                
                if level.isUnlocked {
                    Text("\(level.levelInTier)")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            // Stars
            if level.stars > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < level.stars ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundColor(index < level.stars ? Color("AccentYellow") : .gray.opacity(0.5))
                    }
                }
            } else if level.isUnlocked {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Image(systemName: "star")
                            .font(.system(size: 10))
                            .foregroundColor(.gray.opacity(0.3))
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LevelSelectView()
            .environmentObject(GameManager())
            .environmentObject(LivesManager.shared)
    }
}
