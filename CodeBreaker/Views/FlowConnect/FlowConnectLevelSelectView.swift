import SwiftUI

struct FlowConnectLevelSelectView: View {
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDifficulty: FlowConnectDifficulty = .tiny
    @State private var showingGame = false
    @State private var selectedLevel: FlowConnectLevel?

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

                    Text("Flow Connect")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)

                    Spacer()

                    // Stats
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("\(gameManager.flowConnectTotalStars)")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                }
                .padding()

                // Difficulty selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(FlowConnectDifficulty.allCases, id: \.self) { difficulty in
                            FlowDifficultyTabView(
                                difficulty: difficulty,
                                isSelected: selectedDifficulty == difficulty,
                                isUnlocked: gameManager.isFlowConnectDifficultyUnlocked(difficulty),
                                progress: gameManager.flowConnectDifficultyProgress(difficulty)
                            ) {
                                if gameManager.isFlowConnectDifficultyUnlocked(difficulty) {
                                    withAnimation {
                                        selectedDifficulty = difficulty
                                    }
                                    HapticManager.shared.selection()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                // Levels grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 70, maximum: 80), spacing: 12)
                    ], spacing: 12) {
                        ForEach(gameManager.flowConnectLevels(for: selectedDifficulty)) { level in
                            FlowConnectLevelButton(level: level) {
                                if level.isUnlocked {
                                    selectedLevel = level
                                    showingGame = true
                                    HapticManager.shared.selection()
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showingGame) {
            if let level = selectedLevel {
                FlowConnectView(difficulty: level.difficulty, level: level)
            }
        }
    }
}

// MARK: - Difficulty Tab View

struct FlowDifficultyTabView: View {
    let difficulty: FlowConnectDifficulty
    let isSelected: Bool
    let isUnlocked: Bool
    let progress: (completed: Int, total: Int, stars: Int, maxStars: Int)
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? difficulty.color : Color.white.opacity(0.1))
                        .frame(width: 50, height: 50)

                    if isUnlocked {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                            .font(.title2)
                            .foregroundColor(isSelected ? .white : difficulty.color)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }

                // Name
                Text(difficulty.name)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))

                // Grid size
                Text("\(difficulty.gridSize)x\(difficulty.gridSize)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))

                // Progress
                if isUnlocked {
                    Text("\(progress.completed)/\(progress.total)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? difficulty.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(isUnlocked ? 1.0 : 0.5)
    }
}

// MARK: - Level Button

struct FlowConnectLevelButton: View {
    let level: FlowConnectLevel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(level.isUnlocked ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                        .frame(width: 70, height: 70)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(level.stars > 0 ? level.difficulty.color : Color.white.opacity(0.2), lineWidth: level.stars > 0 ? 2 : 1)
                        )

                    if level.isUnlocked {
                        Text("\(level.levelInDifficulty)")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }

                // Stars
                if level.stars > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<3) { index in
                            Image(systemName: index < level.stars ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundColor(index < level.stars ? .yellow : .gray.opacity(0.5))
                        }
                    }
                } else if level.isUnlocked {
                    HStack(spacing: 2) {
                        ForEach(0..<3) { _ in
                            Image(systemName: "star")
                                .font(.system(size: 10))
                                .foregroundColor(.gray.opacity(0.3))
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(level.isUnlocked ? 1.0 : 0.5)
    }
}

#Preview {
    NavigationStack {
        FlowConnectLevelSelectView()
            .environmentObject(GameManager())
    }
}
