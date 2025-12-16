import SwiftUI

// MARK: - Time Attack View

struct TimeAttackView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var livesManager: LivesManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var game: MastermindGame
    @StateObject private var timer = TimeAttackTimer()

    @State private var selectedPegIndex: Int? = 0
    @State private var dragTargetIndex: Int?
    @State private var isDragging = false
    @State private var showingResult = false
    @State private var puzzlesSolved = 0
    @State private var totalScore = 0

    private let tier: DifficultyTier

    init(tier: DifficultyTier = .beginner) {
        self.tier = tier
        _game = StateObject(wrappedValue: MastermindGame(tier: tier, level: nil))
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

            VStack(spacing: 0) {
                // Header with timer
                TimeAttackHeaderView(
                    timeRemaining: timer.timeRemaining,
                    puzzlesSolved: puzzlesSolved,
                    score: totalScore,
                    onQuit: {
                        timer.stop()
                        HapticManager.shared.navigate()
                        dismiss()
                    }
                )

                // Main game area
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            // Previous guesses
                            ForEach(Array(game.guessHistory.enumerated()), id: \.offset) { index, result in
                                GuessRowView(
                                    result: result,
                                    codeLength: game.codeLength,
                                    attemptNumber: index + 1,
                                    isRevealing: index == game.guessHistory.count - 1
                                )
                                .id(index)
                            }

                            // Current guess row
                            if timer.isRunning {
                                CurrentGuessRowView(
                                    currentGuess: game.currentGuess,
                                    codeLength: game.codeLength,
                                    attemptNumber: game.currentAttempt,
                                    selectedIndex: selectedPegIndex,
                                    dragTargetIndex: dragTargetIndex,
                                    onPegTap: { index in
                                        selectedPegIndex = index
                                        HapticManager.shared.selection()
                                    },
                                    onPegLongPress: { index in
                                        game.clearPosition(at: index)
                                        HapticManager.shared.pegRemoved()
                                        selectedPegIndex = index
                                    },
                                    onDrop: { index, color in
                                        game.setColor(at: index, color: color)
                                        HapticManager.shared.pegPlaced()
                                        SoundManager.shared.pegPlaced()
                                        dragTargetIndex = nil
                                        isDragging = false
                                    },
                                    onDropTargetChanged: { index in
                                        if dragTargetIndex != index {
                                            dragTargetIndex = index
                                            if index != nil {
                                                HapticManager.shared.selection()
                                            }
                                        }
                                    }
                                )
                                .id("current")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: game.guessHistory.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo("current", anchor: .center)
                        }
                    }
                }

                // Color picker and submit button
                if timer.isRunning {
                    VStack(spacing: 16) {
                        ColorPickerView(
                            colors: game.availableColors,
                            onColorSelected: { color in
                                if let index = selectedPegIndex {
                                    game.setColor(at: index, color: color)
                                    HapticManager.shared.pegPlaced()
                                    SoundManager.shared.pegPlaced()
                                    advanceToNextEmptySlot(from: index)
                                }
                            },
                            onDragStarted: {
                                isDragging = true
                            }
                        )

                        HStack(spacing: 12) {
                            Button(action: {
                                game.clearCurrentGuess()
                                selectedPegIndex = 0
                                HapticManager.shared.impact(.light)
                                SoundManager.shared.pegRemoved()
                            }) {
                                Label("Clear", systemImage: "xmark.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Capsule())
                            }

                            Button(action: submitGuess) {
                                Label("Submit", systemImage: "checkmark.circle.fill")
                                    .font(.headline.weight(.bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        game.isGuessComplete
                                            ? Color("AccentGreen")
                                            : Color.gray.opacity(0.5)
                                    )
                                    .clipShape(Capsule())
                            }
                            .disabled(!game.isGuessComplete)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                }
            }

            // Result overlay
            if showingResult {
                TimeAttackResultView(
                    puzzlesSolved: puzzlesSolved,
                    totalScore: totalScore,
                    onPlayAgain: {
                        resetGame()
                        withAnimation {
                            showingResult = false
                        }
                    },
                    onQuit: {
                        dismiss()
                    }
                )
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            timer.start()
            selectedPegIndex = 0
        }
        .onChange(of: timer.timeRemaining) { _, newValue in
            if newValue <= 0 {
                endGame()
            }
        }
        .onChange(of: game.gameState) { _, newState in
            handleGameStateChange(newState)
        }
    }

    private func advanceToNextEmptySlot(from currentIndex: Int) {
        for i in (currentIndex + 1)..<game.codeLength {
            if game.currentGuess[i] == nil {
                selectedPegIndex = i
                return
            }
        }
        for i in 0..<currentIndex {
            if game.currentGuess[i] == nil {
                selectedPegIndex = i
                return
            }
        }
    }

    private func submitGuess() {
        guard game.isGuessComplete else { return }

        HapticManager.shared.guessSubmitted()
        SoundManager.shared.guessSubmitted()

        if let result = game.submitGuess() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                HapticManager.shared.feedbackReveal(blackCount: result.blackCount, whiteCount: result.whiteCount)
            }
        }

        selectedPegIndex = 0
    }

    private func handleGameStateChange(_ state: GameState) {
        switch state {
        case .won(let attempts, _):
            // Calculate score: base points + time bonus + efficiency bonus
            let basePoints = 100
            let timeBonus = Int(timer.timeRemaining) * 2
            let efficiencyBonus = max(0, (game.maxAttempts - attempts) * 25)
            let puzzleScore = basePoints + timeBonus + efficiencyBonus

            puzzlesSolved += 1
            totalScore += puzzleScore

            HapticManager.shared.correctGuess()
            SoundManager.shared.correctGuess()

            // Add bonus time for solving
            timer.addTime(15)

            // Start a new puzzle after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                startNewPuzzle()
            }

        case .lost:
            // No penalty, just start a new puzzle
            HapticManager.shared.gameLost()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startNewPuzzle()
            }

        default:
            break
        }
    }

    private func startNewPuzzle() {
        game.restart()
        selectedPegIndex = 0
    }

    private func endGame() {
        timer.stop()
        HapticManager.shared.gameLost()
        withAnimation {
            showingResult = true
        }
    }

    private func resetGame() {
        puzzlesSolved = 0
        totalScore = 0
        game.restart()
        selectedPegIndex = 0
        timer.reset()
        timer.start()
    }
}

// MARK: - Time Attack Timer

class TimeAttackTimer: ObservableObject {
    @Published var timeRemaining: TimeInterval = 90 // 90 seconds
    @Published var isRunning = false

    private var timer: Timer?
    private let initialTime: TimeInterval = 90

    func start() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 0.1
            } else {
                self.stop()
            }
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func addTime(_ seconds: TimeInterval) {
        timeRemaining += seconds
    }

    func reset() {
        stop()
        timeRemaining = initialTime
    }
}

// MARK: - Time Attack Header

struct TimeAttackHeaderView: View {
    let timeRemaining: TimeInterval
    let puzzlesSolved: Int
    let score: Int
    let onQuit: () -> Void

    var timerColor: Color {
        if timeRemaining <= 10 {
            return .red
        } else if timeRemaining <= 30 {
            return .orange
        } else {
            return .white
        }
    }

    var body: some View {
        HStack {
            Button(action: onQuit) {
                Image(systemName: "xmark")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }

            Spacer()

            // Timer
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .foregroundColor(timerColor)
                Text(formattedTime)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundColor(timerColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
            .scaleEffect(timeRemaining <= 10 ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: timeRemaining <= 10)

            Spacer()

            // Score
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(puzzlesSolved)")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                }
                Text("\(score) pts")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding()
    }

    private var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        let tenths = Int((timeRemaining.truncatingRemainder(dividingBy: 1)) * 10)

        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%d.%d", seconds, tenths)
        }
    }
}

// MARK: - Time Attack Result View

struct TimeAttackResultView: View {
    let puzzlesSolved: Int
    let totalScore: Int
    let onPlayAgain: () -> Void
    let onQuit: () -> Void

    @State private var showContent = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Title
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Color("AccentOrange"))

                    Text("Time's Up!")
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(showContent ? 1 : 0.5)
                .opacity(showContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showContent)

                // Stats
                VStack(spacing: 16) {
                    StatRow(
                        icon: "checkmark.circle.fill",
                        iconColor: .green,
                        label: "Puzzles Solved",
                        value: "\(puzzlesSolved)"
                    )

                    StatRow(
                        icon: "star.fill",
                        iconColor: Color("AccentYellow"),
                        label: "Total Score",
                        value: "\(totalScore)"
                    )

                    StatRow(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: Color("AccentBlue"),
                        label: "Average Score",
                        value: puzzlesSolved > 0 ? "\(totalScore / puzzlesSolved)" : "0"
                    )
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .offset(y: showContent ? 0 : 20)
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.3), value: showContent)

                // Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        HapticManager.shared.primaryButtonTap()
                        onPlayAgain()
                    }) {
                        Label("Play Again", systemImage: "arrow.counterclockwise")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("AccentOrange"))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button(action: {
                        HapticManager.shared.navigate()
                        onQuit()
                    }) {
                        Text("Back to Menu")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 32)
                .offset(y: showContent ? 0 : 20)
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.6), value: showContent)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color("BackgroundTop").opacity(0.95))
            )
            .padding(24)
        }
        .onAppear {
            withAnimation {
                showContent = true
            }
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 30)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    TimeAttackView(tier: .beginner)
        .environmentObject(GameManager())
        .environmentObject(LivesManager.shared)
}
