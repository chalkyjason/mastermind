import SwiftUI

struct BinaryGridView: View {
    @EnvironmentObject var gameManager: GameManager
    @StateObject private var game: BinaryGridGame
    @Environment(\.dismiss) private var dismiss

    @State private var showingWinSheet = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    let level: BinaryGridLevel?

    init(difficulty: BinaryGridDifficulty, level: BinaryGridLevel? = nil) {
        self.level = level
        _game = StateObject(wrappedValue: BinaryGridGame(difficulty: difficulty, level: level))
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
                    elapsedTime: elapsedTime,
                    remainingCells: game.remainingCells,
                    onPause: {
                        HapticManager.shared.navigate()
                        dismiss()
                    }
                )

                Spacer()

                // Grid
                BinaryGridBoardView(game: game)
                    .padding(.horizontal)

                Spacer()

                // Rules reminder and clear button
                VStack(spacing: 16) {
                    // Rules hint
                    HStack(spacing: 16) {
                        RuleHintView(icon: "3.circle", text: "No 3 in a row")
                        RuleHintView(icon: "equal.circle", text: "Equal colors")
                        RuleHintView(icon: "rectangle.stack", text: "Unique rows/cols")
                    }
                    .padding(.horizontal)

                    // Clear button
                    Button(action: {
                        game.clearUserInput()
                    }) {
                        Label("Clear", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
            }

            // Win overlay
            if showingWinSheet {
                BinaryGridWinOverlayView(
                    time: elapsedTime,
                    stars: calculateStars(),
                    gridSize: game.gridSize,
                    onContinue: handleWinContinue,
                    onReplay: handleReplay
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
    }

    private var headerTitle: String {
        if let level = level {
            return level.displayName
        } else {
            return "Practice"
        }
    }

    private func calculateStars() -> Int {
        BinaryGridLevel.calculateStars(time: elapsedTime, gridSize: game.gridSize)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime = game.elapsedTime
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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
        default:
            break
        }
    }

    private func handleWinContinue() {
        if case .won(let time, let stars) = game.gameState {
            if let level = level {
                gameManager.completeBinaryGridLevel(level.id, stars: stars, time: time)
            }
        }
        dismiss()
    }

    private func handleReplay() {
        showingWinSheet = false
        game.restart()
        elapsedTime = 0
        startTimer()
    }
}

// MARK: - Header View

struct BinaryGridHeaderView: View {
    let title: String
    let elapsedTime: TimeInterval
    let remainingCells: Int
    let onPause: () -> Void

    var body: some View {
        HStack {
            Button(action: onPause) {
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

            // Timer and remaining
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(elapsedTime))
                    .font(.headline.monospacedDigit())
                    .foregroundColor(.white)

                Text("\(remainingCells) left")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        let padding: CGFloat = 32 + 16 + CGFloat(game.gridSize - 1) * 2 // horizontal padding + gaps
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
                    // Lock indicator
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
                // Title
                Text("Puzzle Complete!")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)

                // Stars
                HStack(spacing: 12) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.system(size: 44))
                            .foregroundColor(index < stars ? .yellow : .gray)
                            .shadow(color: index < stars ? .yellow.opacity(0.5) : .clear, radius: 8)
                    }
                }

                // Stats
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

                // Buttons
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
