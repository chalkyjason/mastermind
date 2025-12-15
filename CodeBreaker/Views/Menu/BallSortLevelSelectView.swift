import SwiftUI

struct BallSortLevelSelectView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var livesManager: LivesManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDifficulty: BallSortDifficulty = .easy
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

                    Text("Ball Sort")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)

                    Spacer()

                    // Placeholder for balance
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding()

                // Difficulty selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(BallSortDifficulty.allCases, id: \.self) { difficulty in
                            BallSortDifficultyTabButton(
                                difficulty: difficulty,
                                isSelected: selectedDifficulty == difficulty,
                                isUnlocked: gameManager.isBallSortDifficultyUnlocked(difficulty),
                                progress: gameManager.ballSortDifficultyProgress(difficulty)
                            ) {
                                if gameManager.isBallSortDifficultyUnlocked(difficulty) {
                                    withAnimation {
                                        selectedDifficulty = difficulty
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

                // Difficulty info
                BallSortDifficultyInfoBar(
                    difficulty: selectedDifficulty,
                    progress: gameManager.ballSortDifficultyProgress(selectedDifficulty)
                )
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
                        ForEach(gameManager.ballSortLevels(for: selectedDifficulty)) { level in
                            if level.isUnlocked {
                                if livesManager.hasLives {
                                    NavigationLink(destination: BallSortView(difficulty: level.difficulty, level: level)) {
                                        BallSortLevelCell(level: level)
                                    }
                                    .simultaneousGesture(TapGesture().onEnded {
                                        HapticManager.shared.primaryButtonTap()
                                    })
                                } else {
                                    BallSortLevelCell(level: level)
                                        .onTapGesture {
                                            showingNoLivesAlert = true
                                            HapticManager.shared.notification(.warning)
                                        }
                                }
                            } else {
                                BallSortLevelCell(level: level)
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

// MARK: - Ball Sort Difficulty Tab Button

struct BallSortDifficultyTabButton: View {
    let difficulty: BallSortDifficulty
    let isSelected: Bool
    let isUnlocked: Bool
    let progress: (completed: Int, total: Int, stars: Int, maxStars: Int)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? difficulty.color : Color.white.opacity(0.1))
                        .frame(width: 50, height: 50)

                    if isUnlocked {
                        Image(systemName: difficulty.iconName)
                            .font(.title3)
                            .foregroundColor(isSelected ? .white : difficulty.color)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }

                Text(difficulty.name)
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

// MARK: - Ball Sort Difficulty Info Bar

struct BallSortDifficultyInfoBar: View {
    let difficulty: BallSortDifficulty
    let progress: (completed: Int, total: Int, stars: Int, maxStars: Int)

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(difficulty.name)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)

                Text("\(difficulty.colorCount) colors • \(difficulty.colorCount + difficulty.emptyTubes) tubes")
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
        .background(difficulty.color.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Ball Sort Level Cell

struct BallSortLevelCell: View {
    let level: BallSortLevel

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(level.isUnlocked ? level.difficulty.color.opacity(0.3) : Color.gray.opacity(0.2))
                    .frame(height: 50)

                if level.isUnlocked {
                    Text("\(level.levelInDifficulty)")
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
        BallSortLevelSelectView()
            .environmentObject(GameManager())
            .environmentObject(LivesManager.shared)
    }
}
