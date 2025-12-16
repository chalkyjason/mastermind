import SwiftUI
import Foundation

// MARK: - Drag State

struct DraggedBallInfo: Equatable {
    let sourceTubeIndex: Int
    let color: PegColor
    let ballCount: Int
}

struct TubeFrame: Equatable {
    let index: Int
    let frame: CGRect
}

struct TubeFramePreferenceKey: PreferenceKey {
    static var defaultValue: [TubeFrame] = []

    static func reduce(value: inout [TubeFrame], nextValue: () -> [TubeFrame]) {
        value.append(contentsOf: nextValue())
    }
}

struct BallSortView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var livesManager: LivesManager
    @StateObject private var game: BallSortGame
    @Environment(\.dismiss) private var dismiss

    @State private var showingWinSheet = false
    @State private var animatingBall = false
    @State private var movingBallPosition: CGPoint?

    // Drag state
    @State private var draggedBallInfo: DraggedBallInfo?
    @State private var dragPosition: CGPoint = .zero
    @State private var tubeFrames: [TubeFrame] = []
    @State private var highlightedTubeIndex: Int?
    @GestureState private var isDragging = false

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

                // Tubes grid with drag support
                TubesGridView(
                    game: game,
                    draggedBallInfo: $draggedBallInfo,
                    dragPosition: $dragPosition,
                    highlightedTubeIndex: $highlightedTubeIndex,
                    tubeFrames: $tubeFrames,
                    onDragStarted: handleDragStarted,
                    onDragEnded: handleDragEnded
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

            // Dragging ball overlay
            if let dragInfo = draggedBallInfo {
                DraggingBallView(
                    color: dragInfo.color,
                    ballCount: dragInfo.ballCount,
                    position: dragPosition
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

    // MARK: - Drag Handling

    private func handleDragStarted(tubeIndex: Int, position: CGPoint) {
        guard game.gameState == .playing else { return }
        guard let topColor = game.topBall(in: tubeIndex) else { return }

        // Count consecutive same-color balls at top
        let tube = game.tubes[tubeIndex]
        var ballCount = 0
        for i in stride(from: tube.count - 1, through: 0, by: -1) {
            if tube[i] == topColor {
                ballCount += 1
            } else {
                break
            }
        }

        draggedBallInfo = DraggedBallInfo(
            sourceTubeIndex: tubeIndex,
            color: topColor,
            ballCount: ballCount
        )
        dragPosition = position
        HapticManager.shared.selection()
    }

    private func handleDragEnded() {
        guard let dragInfo = draggedBallInfo else { return }

        // Find which tube we're over
        if let targetIndex = highlightedTubeIndex,
           targetIndex != dragInfo.sourceTubeIndex,
           game.canMove(from: dragInfo.sourceTubeIndex, to: targetIndex) {
            // Perform the move
            game.selectTube(at: dragInfo.sourceTubeIndex)
            game.selectTube(at: targetIndex)
            HapticManager.shared.pegPlaced()
            SoundManager.shared.pegPlaced()
        }

        // Reset drag state
        withAnimation(.easeOut(duration: 0.2)) {
            draggedBallInfo = nil
            highlightedTubeIndex = nil
        }
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

    @Binding var draggedBallInfo: DraggedBallInfo?
    @Binding var dragPosition: CGPoint
    @Binding var highlightedTubeIndex: Int?
    @Binding var tubeFrames: [TubeFrame]

    var onDragStarted: (Int, CGPoint) -> Void
    var onDragEnded: () -> Void

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
                            DraggableTubeView(
                                tubeIndex: tubeIndex,
                                balls: game.tubes[tubeIndex],
                                isSelected: game.selectedTubeIndex == tubeIndex,
                                isComplete: game.isTubeComplete(tubeIndex),
                                isHighlighted: highlightedTubeIndex == tubeIndex,
                                isDragSource: draggedBallInfo?.sourceTubeIndex == tubeIndex,
                                colorblindMode: colorblindMode,
                                onDragStarted: onDragStarted,
                                onDragChanged: { position in
                                    dragPosition = position
                                    updateHighlightedTube(at: position)
                                },
                                onDragEnded: onDragEnded
                            )
                            .background(
                                GeometryReader { tubeGeometry in
                                    Color.clear.preference(
                                        key: TubeFramePreferenceKey.self,
                                        value: [TubeFrame(
                                            index: tubeIndex,
                                            frame: tubeGeometry.frame(in: .named("tubesGrid"))
                                        )]
                                    )
                                }
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onPreferenceChange(TubeFramePreferenceKey.self) { frames in
                tubeFrames = frames
            }
        }
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

    private func updateHighlightedTube(at position: CGPoint) {
        guard let dragInfo = draggedBallInfo else {
            highlightedTubeIndex = nil
            return
        }

        // Find which tube the position is over
        for frame in tubeFrames {
            if frame.frame.contains(position) {
                // Check if we can move to this tube
                if frame.index != dragInfo.sourceTubeIndex &&
                   game.canMove(from: dragInfo.sourceTubeIndex, to: frame.index) {
                    if highlightedTubeIndex != frame.index {
                        highlightedTubeIndex = frame.index
                        HapticManager.shared.selection()
                    }
                    return
                }
            }
        }
        highlightedTubeIndex = nil
    }
}

// MARK: - Tube View

struct TubeView: View {
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
                                isSelected ? Color.white : (isComplete ? Color("AccentGreen") : Color.white.opacity(0.3)),
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
}

// MARK: - Draggable Tube View

struct DraggableTubeView: View {
    let tubeIndex: Int
    let balls: [PegColor]
    let isSelected: Bool
    let isComplete: Bool
    let isHighlighted: Bool
    let isDragSource: Bool
    let colorblindMode: Bool
    var onDragStarted: (Int, CGPoint) -> Void
    var onDragChanged: (CGPoint) -> Void
    var onDragEnded: () -> Void

    private let tubeCapacity = 4
    private let ballSize: CGFloat = 36
    private let tubeWidth: CGFloat = 44
    private let tubeHeight: CGFloat = 160

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tube container
            TubeShape()
                .fill(Color.black.opacity(0.6))
                .frame(width: tubeWidth, height: tubeHeight)
                .overlay(
                    TubeShape()
                        .stroke(
                            strokeColor,
                            lineWidth: (isSelected || isHighlighted) ? 3 : 2
                        )
                )

            // Balls inside tube
            VStack(spacing: 2) {
                ForEach(Array(displayBalls.enumerated().reversed()), id: \.offset) { index, color in
                    BallView(
                        color: color,
                        size: ballSize,
                        colorblindMode: colorblindMode,
                        isTopBall: false
                    )
                }
            }
            .padding(.bottom, 8)
        }
        .scaleEffect((isSelected || isHighlighted) ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHighlighted)
        .gesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .named("tubesGrid"))
                .onChanged { value in
                    if !isDragSource && !balls.isEmpty {
                        onDragStarted(tubeIndex, value.location)
                    } else if isDragSource {
                        onDragChanged(value.location)
                    }
                }
                .onEnded { _ in
                    onDragEnded()
                }
        )
    }

    private var strokeColor: Color {
        if isHighlighted {
            return Color("AccentGreen")
        } else if isSelected {
            return Color.white
        } else if isComplete {
            return Color("AccentGreen")
        } else {
            return Color.white.opacity(0.3)
        }
    }

    // Hide top balls when they're being dragged
    private var displayBalls: [PegColor] {
        if isDragSource {
            // Count consecutive same-color balls at top
            guard let topColor = balls.last else { return balls }
            var count = 0
            for i in stride(from: balls.count - 1, through: 0, by: -1) {
                if balls[i] == topColor {
                    count += 1
                } else {
                    break
                }
            }
            // Return balls without the dragged ones
            return Array(balls.dropLast(count))
        }
        return balls
    }
}

// MARK: - Dragging Ball View (Floating)

struct DraggingBallView: View {
    let color: PegColor
    let ballCount: Int
    let position: CGPoint
    @AppStorage("colorblindMode") private var colorblindMode = false

    private let ballSize: CGFloat = 36

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<ballCount, id: \.self) { _ in
                BallView(
                    color: color,
                    size: ballSize,
                    colorblindMode: colorblindMode,
                    isTopBall: false
                )
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .scaleEffect(1.1)
        .position(x: position.x, y: position.y - CGFloat(ballCount * 20))
        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: position)
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
