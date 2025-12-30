import SwiftUI

struct FlowConnectView: View {
    @EnvironmentObject var gameManager: GameManager
    @StateObject private var game: FlowConnectGame
    @Environment(\.dismiss) private var dismiss

    @State private var showingWinSheet = false
    @State private var cellFrames: [GridPosition: CGRect] = [:]

    let level: FlowConnectLevel?

    init(difficulty: FlowConnectDifficulty, level: FlowConnectLevel? = nil) {
        self.level = level
        _game = StateObject(wrappedValue: FlowConnectGame(difficulty: difficulty, level: level))
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
                FlowConnectHeaderView(
                    title: headerTitle,
                    flowsConnected: game.connectedFlowCount(),
                    totalFlows: game.flowColors.count,
                    filledPercentage: game.calculateFilledPercentage(),
                    onBack: {
                        HapticManager.shared.navigate()
                        dismiss()
                    }
                )

                Spacer()

                // Grid
                FlowConnectGridView(
                    game: game,
                    cellFrames: $cellFrames
                )
                .padding(.horizontal)

                Spacer()

                // Bottom controls
                HStack(spacing: 20) {
                    Button(action: {
                        game.clearAll()
                        HapticManager.shared.impact(.medium)
                    }) {
                        Label("Clear", systemImage: "trash.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button(action: {
                        game.restart()
                        HapticManager.shared.gameRestart()
                    }) {
                        Label("Restart", systemImage: "arrow.counterclockwise.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding()
                .padding(.bottom, 20)
            }

            // Win overlay
            if showingWinSheet {
                FlowConnectWinOverlayView(
                    moves: game.moveCount,
                    flowCount: game.flowColors.count,
                    onContinue: handleWinContinue,
                    onReplay: handleReplay
                )
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
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

    private func handleGameStateChange(_ state: FlowConnectState) {
        switch state {
        case .won:
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
        if case .won(let moves, let stars) = game.gameState {
            if let level = level {
                gameManager.completeFlowConnectLevel(level.id, stars: stars, moves: moves)
            }
        }
        dismiss()
    }

    private func handleReplay() {
        showingWinSheet = false
        game.restart()
    }
}

// MARK: - Header View

struct FlowConnectHeaderView: View {
    let title: String
    let flowsConnected: Int
    let totalFlows: Int
    let filledPercentage: Double
    let onBack: () -> Void

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

            // Progress indicator
            VStack(spacing: 2) {
                Text("\(flowsConnected)/\(totalFlows)")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                Text("\(Int(filledPercentage * 100))%")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding()
    }
}

// MARK: - Grid View

struct FlowConnectGridView: View {
    @ObservedObject var game: FlowConnectGame
    @Binding var cellFrames: [GridPosition: CGRect]

    @State private var lastProcessedPosition: GridPosition?

    var body: some View {
        let cellSize = calculateCellSize()
        let spacing: CGFloat = 2

        GeometryReader { geometry in
            let gridWidth = CGFloat(game.gridSize) * cellSize + CGFloat(game.gridSize - 1) * spacing
            let gridHeight = CGFloat(game.gridSize) * cellSize + CGFloat(game.gridSize - 1) * spacing

            ZStack {
                // Grid background
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.4))
                    .frame(width: gridWidth + 16, height: gridHeight + 16)

                // Cells
                VStack(spacing: spacing) {
                    ForEach(0..<game.gridSize, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<game.gridSize, id: \.self) { col in
                                let pos = GridPosition(row: row, col: col)
                                FlowCellView(
                                    cell: game.grid[row][col],
                                    isInCurrentPath: game.currentPath.contains(pos),
                                    currentColor: game.currentDrawingColor,
                                    size: cellSize
                                )
                                .background(
                                    GeometryReader { cellGeo in
                                        Color.clear.onAppear {
                                            cellFrames[pos] = cellGeo.frame(in: .named("flowGrid"))
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(name: "flowGrid")
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("flowGrid"))
                    .onChanged { value in
                        handleDrag(at: value.location, cellSize: cellSize, spacing: spacing)
                    }
                    .onEnded { _ in
                        handleDragEnd()
                    }
            )
        }
    }

    private func calculateCellSize() -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let padding: CGFloat = 64
        let totalSpacing = CGFloat(game.gridSize - 1) * 2
        let availableWidth = screenWidth - padding - totalSpacing
        return min(availableWidth / CGFloat(game.gridSize), 50)
    }

    private func handleDrag(at location: CGPoint, cellSize: CGFloat, spacing: CGFloat) {
        // Find which cell was touched
        for (position, frame) in cellFrames {
            if frame.contains(location) {
                // Only process if it's a new cell
                if lastProcessedPosition != position {
                    lastProcessedPosition = position
                    processTouch(at: position)
                }
                return
            }
        }
    }

    private func processTouch(at position: GridPosition) {
        if game.currentDrawingColor == nil {
            // Try to start drawing
            let cell = game.grid[position.row][position.col]
            if cell.type == .endpoint {
                game.startDrawing(at: position)
                HapticManager.shared.impact(.medium)
                SoundManager.shared.pegPlaced()
            } else {
                // Can't start here
                HapticManager.shared.notification(.warning)
            }
        } else {
            // Continue drawing
            let previousPathCount = game.currentPath.count
            game.continueDrawing(to: position)

            if game.currentPath.count > previousPathCount {
                // Successfully extended path
                HapticManager.shared.impact(.light)
            } else if game.currentPath.count < previousPathCount {
                // Backtracked
                HapticManager.shared.impact(.soft)
            }
            // If path count unchanged, move was invalid (no feedback needed)
        }
    }

    private func handleDragEnd() {
        lastProcessedPosition = nil

        let wasConnected = game.currentPath.count >= 2 &&
            game.currentPath.first.map { game.grid[$0.row][$0.col].type == .endpoint } == true &&
            game.currentPath.last.map { game.grid[$0.row][$0.col].type == .endpoint } == true &&
            game.currentPath.first.flatMap { game.grid[$0.row][$0.col].color } ==
            game.currentPath.last.flatMap { game.grid[$0.row][$0.col].color }

        game.endDrawing()

        if wasConnected {
            HapticManager.shared.notification(.success)
            SoundManager.shared.correctGuess()
        } else if game.currentPath.isEmpty == false {
            // Path was incomplete
            HapticManager.shared.notification(.error)
        }
    }
}

// MARK: - Cell View

struct FlowCellView: View {
    let cell: FlowCell
    let isInCurrentPath: Bool
    let currentColor: FlowColor?
    let size: CGFloat

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor)
                .frame(width: size, height: size)

            // Endpoint dot
            if cell.type == .endpoint, let color = cell.color {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                color.color.opacity(0.9),
                                color.color
                            ]),
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: size * 0.5
                        )
                    )
                    .frame(width: size * 0.7, height: size * 0.7)
                    .shadow(color: color.color.opacity(0.6), radius: 4, y: 2)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: size * 0.7, height: size * 0.7)
                    )
            }

            // Committed path segment
            if cell.type == .path, let color = cell.color {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.color.opacity(0.8))
                    .frame(width: size * 0.55, height: size * 0.55)
            }

            // Current drawing path (preview)
            if isInCurrentPath, let color = currentColor {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.color.opacity(0.6))
                    .frame(width: size * 0.55, height: size * 0.55)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(color.color, lineWidth: 2)
                            .frame(width: size * 0.55, height: size * 0.55)
                    )
            }
        }
    }

    private var backgroundColor: Color {
        if isInCurrentPath {
            return Color.white.opacity(0.2)
        } else if cell.type == .path {
            return Color.white.opacity(0.1)
        }
        return Color.white.opacity(0.08)
    }
}

// MARK: - Win Overlay View

struct FlowConnectWinOverlayView: View {
    let moves: Int
    let flowCount: Int
    let onContinue: () -> Void
    let onReplay: () -> Void

    @State private var starAnimations: [Bool] = [false, false, false]
    @State private var showConfetti = false
    @State private var showContent = false

    var stars: Int {
        FlowConnectLevel.calculateStars(moves: moves, flowCount: flowCount)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
            }

            VStack(spacing: 24) {
                Text("Puzzle Complete!")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)

                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color("AccentBlue"), Color("AccentPurple")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(showContent ? 1 : 0)
                    .opacity(showContent ? 1 : 0)

                Text("Connected in \(moves) moves")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))

                HStack(spacing: 12) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.system(size: 44))
                            .foregroundColor(index < stars ? .yellow : .gray)
                            .scaleEffect(starAnimations[index] ? 1.2 : 0.5)
                            .opacity(starAnimations[index] ? 1 : 0.3)
                    }
                }

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
        .onAppear {
            showConfetti = true
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showContent = true
            }
            for i in 0..<stars {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2 + 0.5) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        starAnimations[i] = true
                    }
                    HapticManager.shared.starEarned()
                    SoundManager.shared.starEarned()
                }
            }
        }
    }
}

#Preview {
    FlowConnectView(difficulty: .tiny, level: FlowConnectLevel(id: 0, difficulty: .tiny, levelInDifficulty: 1, isUnlocked: true))
        .environmentObject(GameManager())
}
