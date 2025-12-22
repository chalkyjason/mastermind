import SwiftUI
import Foundation

// MARK: - Ball Sort View

struct BallSortView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var livesManager: LivesManager
    @StateObject private var game: BallSortGame
    @Environment(\.dismiss) private var dismiss

    @State private var showingWinSheet = false

    // Animation state for ball transfer
    @State private var animatingBallTransfer = false
    @State private var transferringBalls: [PegColor] = []
    @State private var transferSourceFrame: CGRect = .zero
    @State private var transferTargetFrame: CGRect = .zero
    @State private var ballPosition: CGPoint = .zero
    @State private var tubeFrames: [Int: CGRect] = [:]

    let level: BallSortLevel?

    init(difficulty: BallSortDifficulty, level: BallSortLevel? = nil) {
        self.level = level
        _game = StateObject(wrappedValue: BallSortGame(difficulty: difficulty, level: level))
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
                BallSortHeaderView(
                    title: headerTitle,
                    moveCount: game.moveCount,
                    onPause: {
                        HapticManager.shared.navigate()
                        dismiss()
                    }
                )

                Spacer()

                // Tubes grid with tap support
                TubesGridView(
                    game: game,
                    tubeFrames: $tubeFrames,
                    animatingBallTransfer: animatingBallTransfer,
                    transferSourceIndex: game.selectedTubeIndex,
                    onTubeTapped: handleTubeTapped
                )
                .padding(.horizontal, 16)
                .coordinateSpace(name: "tubesGrid")

                Spacer()

                // Bottom controls
                if game.gameState == .playing {
                    HStack(spacing: 20) {
                        // Undo button
                        Button(action: {
                            game.undo()
                            HapticManager.shared.impact(.light)
                            SoundManager.shared.pegRemoved()
                        }) {
                            Label("Undo", systemImage: "arrow.uturn.backward.circle.fill")
                                .font(.headline)
                                .foregroundColor(game.canUndo ? .white : .white.opacity(0.3))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(game.canUndo ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .disabled(!game.canUndo)
                        .buttonStyle(ScaleButtonStyle())

                        // Restart button
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
            }

            // Animated ball transfer overlay
            if animatingBallTransfer && !transferringBalls.isEmpty {
                TransferringBallsView(
                    balls: transferringBalls,
                    position: ballPosition
                )
            }

            // Win overlay
            if showingWinSheet {
                BallSortWinOverlayView(
                    moves: game.moveCount,
                    targetMoves: game.difficulty.targetMoves,
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

    private func handleGameStateChange(_ state: BallSortGameState) {
        switch state {
        case .won:
            HapticManager.shared.correctGuess()
            SoundManager.shared.correctGuess()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
                gameManager.completeBallSortLevel(level.id, stars: stars, moves: moves)
            }
        }
        dismiss()
    }

    private func handleReplay() {
        showingWinSheet = false
        game.restart()
    }

    // MARK: - Tap Handling

    private func handleTubeTapped(_ tubeIndex: Int) {
        guard game.gameState == .playing else { return }
        guard !animatingBallTransfer else { return }

        // If no tube is selected, select this one (if it has balls)
        if game.selectedTubeIndex == nil {
            if !game.tubes[tubeIndex].isEmpty {
                game.selectTube(at: tubeIndex)
                HapticManager.shared.selection()
            }
        } else {
            // A tube is already selected
            let sourceIndex = game.selectedTubeIndex!

            // Tapping the same tube deselects
            if tubeIndex == sourceIndex {
                game.deselectTube()
                HapticManager.shared.selection()
                return
            }

            // Try to move to the target tube
            if game.canMove(from: sourceIndex, to: tubeIndex) {
                // Animate the ball transfer
                animateBallTransfer(from: sourceIndex, to: tubeIndex)
            } else {
                // Can't move there - if target has balls, select it instead
                if !game.tubes[tubeIndex].isEmpty {
                    game.deselectTube()
                    game.selectTube(at: tubeIndex)
                    HapticManager.shared.selection()
                } else {
                    // Invalid move to empty tube - provide feedback
                    HapticManager.shared.notification(.warning)
                }
            }
        }
    }

    private func animateBallTransfer(from sourceIndex: Int, to targetIndex: Int) {
        guard let sourceFrame = tubeFrames[sourceIndex],
              let targetFrame = tubeFrames[targetIndex] else {
            // Fallback: just do the move without animation
            performMove(from: sourceIndex, to: targetIndex)
            return
        }

        // Get the balls being transferred (consecutive same-color balls at top)
        let sourceTube = game.tubes[sourceIndex]
        guard let topColor = sourceTube.last else { return }

        var ballsToTransfer: [PegColor] = []
        for i in stride(from: sourceTube.count - 1, through: 0, by: -1) {
            if sourceTube[i] == topColor {
                ballsToTransfer.append(topColor)
            } else {
                break
            }
        }

        // Calculate how many can actually fit
        let targetTube = game.tubes[targetIndex]
        let spaceAvailable = 4 - targetTube.count
        let ballsMoving = min(ballsToTransfer.count, spaceAvailable)
        transferringBalls = Array(repeating: topColor, count: ballsMoving)

        // Calculate start and end positions
        let startY = sourceFrame.minY - CGFloat(ballsMoving) * 20
        let endY = targetFrame.minY - CGFloat(targetTube.count + ballsMoving) * 20

        ballPosition = CGPoint(x: sourceFrame.midX, y: startY)
        transferSourceFrame = sourceFrame
        transferTargetFrame = targetFrame

        animatingBallTransfer = true
        HapticManager.shared.impact(.light)

        // Animate: first lift up, then move across, then drop down
        let liftHeight: CGFloat = -60

        // Phase 1: Lift up
        withAnimation(.easeOut(duration: 0.15)) {
            ballPosition = CGPoint(x: sourceFrame.midX, y: sourceFrame.minY + liftHeight)
        }

        // Phase 2: Move across (after lift)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.2)) {
                ballPosition = CGPoint(x: targetFrame.midX, y: targetFrame.minY + liftHeight)
            }
        }

        // Phase 3: Drop down (after move across)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeIn(duration: 0.15)) {
                ballPosition = CGPoint(x: targetFrame.midX, y: endY + 60)
            }
        }

        // Complete the move
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            performMove(from: sourceIndex, to: targetIndex)
            animatingBallTransfer = false
            transferringBalls = []
        }
    }

    private func performMove(from sourceIndex: Int, to targetIndex: Int) {
        game.selectTube(at: sourceIndex)
        game.selectTube(at: targetIndex)
        HapticManager.shared.pegPlaced()
        SoundManager.shared.pegPlaced()
    }
}

// MARK: - Ball Sort Header

struct BallSortHeaderView: View {
    let title: String
    let moveCount: Int
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

            // Move counter
            HStack(spacing: 4) {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(Color("AccentYellow"))
                Text("\(moveCount)")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
        }
        .padding()
    }
}

// MARK: - Tubes Grid View

struct TubesGridView: View {
    @ObservedObject var game: BallSortGame
    @AppStorage("colorblindMode") private var colorblindMode = false

    @Binding var tubeFrames: [Int: CGRect]
    let animatingBallTransfer: Bool
    let transferSourceIndex: Int?
    var onTubeTapped: (Int) -> Void

    var body: some View {
        let columns = calculateColumns()

        GeometryReader { geometry in
            VStack(spacing: 24) {
                // Split tubes into rows
                let tubesPerRow = columns
                let rows = stride(from: 0, to: game.numberOfTubes, by: tubesPerRow).map { startIndex in
                    Array(0..<min(tubesPerRow, game.numberOfTubes - startIndex)).map { startIndex + $0 }
                }

                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 12) {
                        ForEach(row, id: \.self) { tubeIndex in
                            TappableTubeView(
                                tubeIndex: tubeIndex,
                                balls: displayBalls(for: tubeIndex),
                                isSelected: game.selectedTubeIndex == tubeIndex,
                                isComplete: game.isTubeComplete(tubeIndex),
                                colorblindMode: colorblindMode,
                                onTap: { onTubeTapped(tubeIndex) }
                            )
                            .background(
                                GeometryReader { tubeGeometry in
                                    Color.clear
                                        .onAppear {
                                            tubeFrames[tubeIndex] = tubeGeometry.frame(in: .named("tubesGrid"))
                                        }
                                        .onChange(of: tubeGeometry.frame(in: .named("tubesGrid"))) { _, newFrame in
                                            tubeFrames[tubeIndex] = newFrame
                                        }
                                }
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func displayBalls(for tubeIndex: Int) -> [PegColor] {
        // Hide balls being animated from source tube
        if animatingBallTransfer && transferSourceIndex == tubeIndex {
            let balls = game.tubes[tubeIndex]
            guard let topColor = balls.last else { return balls }

            // Count consecutive same-color balls at top
            var count = 0
            for i in stride(from: balls.count - 1, through: 0, by: -1) {
                if balls[i] == topColor {
                    count += 1
                } else {
                    break
                }
            }
            return Array(balls.dropLast(count))
        }
        return game.tubes[tubeIndex]
    }

    private func calculateColumns() -> Int {
        let tubeCount = game.numberOfTubes
        if tubeCount <= 6 {
            return min(tubeCount, 6)
        } else if tubeCount <= 8 {
            return 4
        } else if tubeCount <= 12 {
            return 6
        } else {
            return 7
        }
    }
}

// MARK: - Tappable Tube View

struct TappableTubeView: View {
    let tubeIndex: Int
    let balls: [PegColor]
    let isSelected: Bool
    let isComplete: Bool
    let colorblindMode: Bool
    let onTap: () -> Void

    private let tubeCapacity = 4
    private let ballSize: CGFloat = 36
    private let tubeWidth: CGFloat = 44
    private let tubeHeight: CGFloat = 160

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                // Tube container
                TubeShape()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: tubeWidth, height: tubeHeight)
                    .overlay(
                        TubeShape()
                            .stroke(
                                strokeColor,
                                lineWidth: isSelected ? 3 : 2
                            )
                    )

                // Balls inside tube
                VStack(spacing: 2) {
                    ForEach(Array(balls.enumerated().reversed()), id: \.offset) { index, color in
                        BallView(
                            color: color,
                            size: ballSize,
                            colorblindMode: colorblindMode,
                            isTopBall: index == balls.count - 1 && isSelected
                        )
                    }
                }
                .padding(.bottom, 8)
            }
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var strokeColor: Color {
        if isSelected {
            return Color.white
        } else if isComplete {
            return Color("AccentGreen")
        } else {
            return Color.white.opacity(0.3)
        }
    }
}

// MARK: - Transferring Balls View (Animated Overlay)

struct TransferringBallsView: View {
    let balls: [PegColor]
    let position: CGPoint
    @AppStorage("colorblindMode") private var colorblindMode = false

    private let ballSize: CGFloat = 36

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(balls.enumerated()), id: \.offset) { _, color in
                BallView(
                    color: color,
                    size: ballSize,
                    colorblindMode: colorblindMode,
                    isTopBall: false
                )
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
        .scaleEffect(1.1)
        .position(position)
        .allowsHitTesting(false)
    }
}

// MARK: - Tube Shape

struct TubeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let cornerRadius: CGFloat = 12
        let topInset: CGFloat = 0

        // Start from top-left (open top)
        path.move(to: CGPoint(x: 0, y: topInset))

        // Left side
        path.addLine(to: CGPoint(x: 0, y: rect.height - cornerRadius))

        // Bottom-left corner
        path.addQuadCurve(
            to: CGPoint(x: cornerRadius, y: rect.height),
            control: CGPoint(x: 0, y: rect.height)
        )

        // Bottom
        path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: rect.height))

        // Bottom-right corner
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height - cornerRadius),
            control: CGPoint(x: rect.width, y: rect.height)
        )

        // Right side
        path.addLine(to: CGPoint(x: rect.width, y: topInset))

        return path
    }
}

// MARK: - Ball View

struct BallView: View {
    let color: PegColor
    let size: CGFloat
    let colorblindMode: Bool
    var isTopBall: Bool = false

    var body: some View {
        ZStack {
            // Ball with gradient for 3D effect
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            color.color.opacity(0.9),
                            color.color,
                            color.color.opacity(0.8)
                        ]),
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    // Highlight
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0)
                                ]),
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: size * 0.5
                            )
                        )
                        .frame(width: size * 0.6, height: size * 0.6)
                        .offset(x: -size * 0.15, y: -size * 0.15)
                )
                .shadow(color: color.color.opacity(0.5), radius: 4, y: 2)

            // Colorblind pattern
            if colorblindMode {
                Image(systemName: color.pattern)
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
        }
        .offset(y: isTopBall ? -8 : 0)
        .animation(.easeInOut(duration: 0.15), value: isTopBall)
    }
}

// MARK: - Ball Sort Win Overlay

struct BallSortWinOverlayView: View {
    let moves: Int
    let targetMoves: Int
    let onContinue: () -> Void
    let onReplay: () -> Void

    @State private var showingStars = false
    @State private var starAnimations: [Bool] = [false, false, false]
    @State private var showConfetti = false
    @State private var showContent = false

    var stars: Int {
        BallSortLevel.calculateStars(moves: moves, minMoves: targetMoves)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            // Confetti
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
            }

            VStack(spacing: 24) {
                // Title
                Text("Puzzle Solved!")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showContent)

                // Tubes icon
                Image(systemName: "testtube.2")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color("AccentGreen"), Color("AccentBlue")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(showContent ? 1 : 0)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2), value: showContent)

                // Moves info
                Text("Completed in \(moves) moves")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeIn(duration: 0.3).delay(0.5), value: showContent)

                // Stars
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.system(size: 48))
                            .foregroundColor(index < stars ? Color("AccentYellow") : .gray)
                            .scaleEffect(starAnimations[index] ? 1.2 : 0.5)
                            .opacity(starAnimations[index] ? 1 : 0.3)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.6)
                                    .delay(Double(index) * 0.2),
                                value: starAnimations[index]
                            )
                    }
                }
                .padding(.vertical, 16)

                // Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        HapticManager.shared.primaryButtonTap()
                        onContinue()
                    }) {
                        Text("Continue")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("AccentGreen"))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button(action: {
                        HapticManager.shared.gameRestart()
                        onReplay()
                    }) {
                        Text("Play Again")
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
                .animation(.easeOut(duration: 0.4).delay(1.2), value: showContent)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color("BackgroundTop").opacity(0.95))
            )
            .padding(24)
        }
        .onAppear {
            showConfetti = true

            withAnimation {
                showContent = true
            }

            // Animate stars with haptics and sound
            for i in 0..<stars {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2 + 0.8) {
                    starAnimations[i] = true
                    HapticManager.shared.starEarned()
                    SoundManager.shared.starEarned()
                }
            }
        }
    }
}

#Preview {
    BallSortView(difficulty: .easy, level: BallSortLevel(id: 0, difficulty: .easy, levelInDifficulty: 1, isUnlocked: true))
        .environmentObject(GameManager())
        .environmentObject(LivesManager.shared)
}
