import SwiftUI

struct BinaryGridView: View {
    @EnvironmentObject var gameManager: GameManager
    @StateObject private var game: BinaryGridGame
    @Environment(\.dismiss) private var dismiss

    @State private var showingWinSheet = false
    @State private var showingLoseSheet = false
    @State private var timeRemaining: TimeInterval
    @State private var timer: Timer?

    let level: BinaryGridLevel?
    let timeLimit: TimeInterval

    init(difficulty: BinaryGridDifficulty, level: BinaryGridLevel? = nil) {
        self.level = level
        _game = StateObject(wrappedValue: BinaryGridGame(difficulty: difficulty, level: level))

        // Time limit scales with grid size: 2 minutes for 4x4, scaling up
        let baseTime: TimeInterval = switch difficulty {
        case .tiny: 120      // 2 minutes
        case .small: 180     // 3 minutes
        case .medium: 300    // 5 minutes
        case .large: 420     // 7 minutes
        case .huge: 600      // 10 minutes
        }
        self.timeLimit = baseTime
        _timeRemaining = State(initialValue: baseTime)
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
                // Header
                BinaryGridHeaderView(
                    title: headerTitle,
                    timeRemaining: timeRemaining,
                    timeLimit: timeLimit,
                    remainingCells: game.remainingCells,
                    errorCount: game.errorCells.count,
                    onBack: {
                        HapticManager.shared.navigate()
                        dismiss()
                    }
                )

                Spacer()

                // Grid
                BinaryGridBoardView(game: game)
                    .padding(.horizontal)

                Spacer()

                // Bottom controls
                VStack(spacing: 16) {
                    // Error indicator
                    if game.errorCells.count > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("\(game.errorCells.count) rule violation\(game.errorCells.count == 1 ? "" : "s")")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.2))
                        .clipShape(Capsule())
                    }

                    // Rules hint
                    HStack(spacing: 16) {
                        RuleHintView(icon: "3.circle", text: "No 3 in a row")
                        RuleHintView(icon: "equal.circle", text: "Equal colors")
                        RuleHintView(icon: "rectangle.stack", text: "Unique rows/cols")
                    }
                    .padding(.horizontal)

                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            dismiss()
                        }) {
                            Label("Menu", systemImage: "house.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }

                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            handleReplay()
                        }) {
                            Label("Restart", systemImage: "arrow.counterclockwise")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }

                        Button(action: {
                            game.clearUserInput()
                        }) {
                            Label("Clear", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
            }

            // Win overlay
            if showingWinSheet {
                BinaryGridWinOverlayView(
                    time: timeLimit - timeRemaining,
                    stars: calculateStars(),
                    gridSize: game.gridSize,
                    onContinue: handleWinContinue,
                    onReplay: handleReplay
                )
                .transition(.opacity)
            }

            // Lose overlay (time's up)
            if showingLoseSheet {
                BinaryGridLoseOverlayView(
                    gridSize: game.gridSize,
                    onRetry: handleReplay,
                    onMenu: { dismiss() }
                )
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: game.gameState) { _, newState in
            handleGameStateChange(newState)
        }
        .onReceive(game.objectWillChange) { _ in
            // Additional check for win state when object changes
            DispatchQueue.main.async {
                if case .won = game.gameState, !showingWinSheet {
                    handleGameStateChange(game.gameState)
                }
            }
        }
    }

    private var headerTitle: String {
        if let level = level {
            return level.displayName
        } else {
            return "Practice"
        }
    }

    private func calculateStars() -> Int {
        let elapsedTime = timeLimit - timeRemaining
        return BinaryGridLevel.calculateStars(time: elapsedTime, gridSize: game.gridSize)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1

                // Warning haptic at 30 seconds
                if timeRemaining == 30 {
                    HapticManager.shared.notification(.warning)
                }
                // Warning haptic at 10 seconds
                if timeRemaining == 10 {
                    HapticManager.shared.notification(.warning)
                }
            } else {
                // Time's up!
                handleTimeUp()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func handleTimeUp() {
        stopTimer()
        game.gameState = .lost
        HapticManager.shared.notification(.error)
        SoundManager.shared.wrongGuess()
        withAnimation {
            showingLoseSheet = true
        }
    }

    private func handleGameStateChange(_ state: BinaryGridState) {
        switch state {
        case .won:
            stopTimer()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    showingWinSheet = true
                }
            }
        case .lost:
            stopTimer()
        default:
            break
        }
    }

    private func handleWinContinue() {
        if case .won = game.gameState {
            let elapsedTime = timeLimit - timeRemaining
            let stars = BinaryGridLevel.calculateStars(time: elapsedTime, gridSize: game.gridSize)
            if let level = level {
                gameManager.completeBinaryGridLevel(level.id, stars: stars, time: elapsedTime)
            }
        }
        dismiss()
    }

    private func handleReplay() {
        showingWinSheet = false
        showingLoseSheet = false
        game.restart()
        timeRemaining = timeLimit
        startTimer()
    }
}

// MARK: - Header View

struct BinaryGridHeaderView: View {
    let title: String
    let timeRemaining: TimeInterval
    let timeLimit: TimeInterval
    let remainingCells: Int
    let errorCount: Int
    let onBack: () -> Void

    private var timeProgress: Double {
        timeRemaining / timeLimit
    }

    private var timeColor: Color {
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
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }

            Spacer()

            Text(title)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)

            Spacer()

            // Timer with progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)

                // Progress ring
                Circle()
                    .trim(from: 0, to: timeProgress)
                    .stroke(timeColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text(formatTime(timeRemaining))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundColor(timeColor)

                    Text("\(remainingCells)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Grid Board View

struct BinaryGridBoardView: View {
    @ObservedObject var game: BinaryGridGame
    @AppStorage("colorblindMode") private var colorblindMode = false

    var body: some View {
        let cellSize = calculateCellSize()

        VStack(spacing: 2) {
            ForEach(0..<game.gridSize, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<game.gridSize, id: \.self) { col in
                        BinaryGridCellView(
                            cell: game.grid[row][col],
                            isLocked: game.lockedCells[row][col],
                            isError: game.errorCells.contains(CellPosition(row: row, col: col)),
                            colorblindMode: colorblindMode,
                            size: cellSize
                        ) {
                            game.toggleCell(row: row, col: col)
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func calculateCellSize() -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let padding: CGFloat = 32 + 16 + CGFloat(game.gridSize - 1) * 2
        let availableWidth = screenWidth - padding
        return min(availableWidth / CGFloat(game.gridSize), 50)
    }
}

// MARK: - Cell View

struct BinaryGridCellView: View {
    let cell: BinaryGridCell
    let isLocked: Bool
    let isError: Bool
    let colorblindMode: Bool
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(cellBackgroundColor)
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(borderColor, lineWidth: isError ? 2 : 1)
                    )

                if cell != .empty {
                    Circle()
                        .fill(cell.color)
                        .frame(width: size * 0.7, height: size * 0.7)
                        .shadow(color: cell.color.opacity(0.5), radius: 4, y: 2)

                    if colorblindMode {
                        Image(systemName: cell.pattern)
                            .font(.system(size: size * 0.35, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                if isLocked && cell != .empty {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: size * 0.7, height: size * 0.7)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isLocked)
    }

    private var cellBackgroundColor: Color {
        if isError {
            return Color.red.opacity(0.2)
        } else if isLocked {
            return Color.white.opacity(0.05)
        } else {
            return Color.white.opacity(0.1)
        }
    }

    private var borderColor: Color {
        if isError {
            return Color.red
        } else {
            return Color.white.opacity(0.2)
        }
    }
}

// MARK: - Rule Hint View

struct RuleHintView: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white.opacity(0.7))
            Text(text)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

// MARK: - Win Overlay View

struct BinaryGridWinOverlayView: View {
    let time: TimeInterval
    let stars: Int
    let gridSize: Int
    let onContinue: () -> Void
    let onReplay: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Puzzle Complete!")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.system(size: 44))
                            .foregroundColor(index < stars ? .yellow : .gray)
                            .shadow(color: index < stars ? .yellow.opacity(0.5) : .clear, radius: 8)
                    }
                }

                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                        Text("Time: \(formatTime(time))")
                            .foregroundColor(.white)
                    }

                    HStack {
                        Image(systemName: "square.grid.3x3.fill")
                            .foregroundColor(.purple)
                        Text("Grid: \(gridSize) x \(gridSize)")
                            .foregroundColor(.white)
                    }
                }
                .font(.headline)

                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text("Continue")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("AccentGreen"))
                            .clipShape(Capsule())
                    }

                    Button(action: onReplay) {
                        Label("Play Again", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 32)
            }
            .padding(32)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Lose Overlay View

struct BinaryGridLoseOverlayView: View {
    let gridSize: Int
    let onRetry: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "clock.badge.xmark.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)

                Text("Time's Up!")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)

                Text("You ran out of time to complete the \(gridSize)x\(gridSize) puzzle.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    Button(action: onRetry) {
                        Label("Try Again", systemImage: "arrow.counterclockwise")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("AccentBlue"))
                            .clipShape(Capsule())
                    }

                    Button(action: onMenu) {
                        Label("Back to Menu", systemImage: "house.fill")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 32)
            }
            .padding(32)
        }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    BinaryGridView(difficulty: .small, level: BinaryGridLevel(id: 0, difficulty: .small, levelInDifficulty: 1, isUnlocked: true))
        .environmentObject(GameManager())
}
