import SwiftUI
import Foundation

struct GameView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var livesManager: LivesManager
    @StateObject private var game: MastermindGame
    @ObservedObject private var adManager = AdManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingColorPicker = false
    @State private var selectedPegIndex: Int?
    @State private var showingWinSheet = false
    @State private var showingLoseSheet = false
    @State private var animatingFeedback = false
    @State private var revealedPegs: Set<Int> = []
    @State private var dragTargetIndex: Int?
    @State private var isDragging = false
    @State private var showingHint = false
    @State private var currentHint: KnuthSolver.HintResult?
    @State private var isCalculatingHint = false

    let level: GameLevel?
    let isDaily: Bool
    
    init(tier: DifficultyTier, level: GameLevel? = nil, customCode: [PegColor]? = nil, isDaily: Bool = false) {
        self.level = level
        self.isDaily = isDaily
        _game = StateObject(wrappedValue: MastermindGame(tier: tier, level: level, customCode: customCode))
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
                GameHeaderView(
                    title: headerTitle,
                    attemptsRemaining: game.attemptsRemaining,
                    maxAttempts: game.maxAttempts,
                    onPause: {
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
                            if game.gameState == .playing {
                                CurrentGuessRowView(
                                    currentGuess: game.currentGuess,
                                    codeLength: game.codeLength,
                                    attemptNumber: game.currentAttempt,
                                    selectedIndex: selectedPegIndex,
                                    dragTargetIndex: dragTargetIndex,
                                    onPegTap: { index in
                                        selectedPegIndex = index
                                        showingColorPicker = true
                                        HapticManager.shared.selection()
                                    },
                                    onPegLongPress: { index in
                                        // Long press clears the peg
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
                            
                            // Empty rows for remaining attempts
                            if game.currentAttempt < game.maxAttempts {
                                ForEach(game.currentAttempt..<game.maxAttempts, id: \.self) { index in
                                    EmptyRowView(codeLength: game.codeLength, attemptNumber: index + 1)
                                }
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
                if game.gameState == .playing {
                    VStack(spacing: 16) {
                        ColorPickerView(
                            colors: game.availableColors,
                            onColorSelected: { color in
                                if let index = selectedPegIndex {
                                    game.setColor(at: index, color: color)
                                    HapticManager.shared.pegPlaced()
                                    SoundManager.shared.pegPlaced()

                                    // Auto-advance to next empty slot
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

                            Button(action: requestHint) {
                                Group {
                                    if isCalculatingHint {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        HStack(spacing: 4) {
                                            Image(systemName: "lightbulb.fill")
                                            Text("\(gameManager.hintsRemaining)")
                                                .font(.caption.weight(.bold))
                                        }
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(gameManager.canUseHint ? .yellow : .gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(gameManager.canUseHint ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.2))
                                .clipShape(Capsule())
                            }
                            .disabled(isCalculatingHint || !gameManager.canUseHint)

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
            
            // Win/Lose overlays
            if showingWinSheet {
                WinOverlayView(
                    attempts: game.guessHistory.count,
                    maxAttempts: game.maxAttempts,
                    secretCode: game.secretCode,
                    isDaily: isDaily,
                    guessHistory: game.guessHistory,
                    onContinue: handleWinContinue,
                    onReplay: handleReplay
                )
                .transition(.opacity)
            }
            
            if showingLoseSheet {
                LoseOverlayView(
                    secretCode: game.secretCode,
                    canWatchAd: game.canUseExtraLife,
                    isAdReady: adManager.isRewardedAdReady,
                    onWatchAd: handleWatchAd,
                    onRetry: handleReplay,
                    onQuit: { dismiss() }
                )
                .transition(.opacity)
            }

            // Hint overlay
            if showingHint, let hint = currentHint {
                HintOverlayView(
                    hint: hint,
                    onApply: {
                        applyHint(hint)
                        withAnimation {
                            showingHint = false
                        }
                    },
                    onDismiss: {
                        withAnimation {
                            showingHint = false
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            selectedPegIndex = 0
        }
        .onChange(of: game.gameState) { _, newState in
            handleGameStateChange(newState)
        }
    }
    
    private var headerTitle: String {
        if isDaily {
            return "Daily Challenge"
        } else if let level = level {
            return level.displayName
        } else {
            return "Practice"
        }
    }
    
    private func advanceToNextEmptySlot(from currentIndex: Int) {
        // Find next empty slot
        for i in (currentIndex + 1)..<game.codeLength {
            if game.currentGuess[i] == nil {
                selectedPegIndex = i
                return
            }
        }
        // If no empty slot after, check before
        for i in 0..<currentIndex {
            if game.currentGuess[i] == nil {
                selectedPegIndex = i
                return
            }
        }
        // All slots filled, keep current selection
    }
    
    private func submitGuess() {
        guard game.isGuessComplete else { return }

        HapticManager.shared.guessSubmitted()
        SoundManager.shared.guessSubmitted()

        if let result = game.submitGuess() {
            // Trigger haptic feedback for result
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                HapticManager.shared.feedbackReveal(blackCount: result.blackCount, whiteCount: result.whiteCount)
            }
        }

        selectedPegIndex = 0
    }
    
    private func handleGameStateChange(_ state: GameState) {
        switch state {
        case .won:
            HapticManager.shared.correctGuess()
            SoundManager.shared.correctGuess()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showingWinSheet = true
                }
            }

        case .lost:
            HapticManager.shared.gameLost()
            SoundManager.shared.gameLost()
            livesManager.useLife()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showingLoseSheet = true
                }
            }

        default:
            break
        }
    }
    
    private func handleWinContinue() {
        if case .won(let attempts, let stars) = game.gameState {
            if isDaily {
                gameManager.completeDailyChallenge(attempts: attempts, stars: stars)
            } else if let level = level {
                gameManager.completeLevel(level.id, stars: stars, attempts: attempts)
            }
        }
        dismiss()
    }
    
    private func handleWatchAd() {
        adManager.showRewardedAd { [self] success in
            if success {
                // User watched the ad and earned a reward
                withAnimation {
                    showingLoseSheet = false
                }
                game.addExtraLife()
                selectedPegIndex = 0

                // Haptic feedback for earning the extra life
                HapticManager.shared.levelUnlocked()
            }
            // If not successful, user closed ad early - overlay stays visible
        }
    }

    private func handleReplay() {
        showingWinSheet = false
        showingLoseSheet = false
        game.restart()
        selectedPegIndex = 0
    }

    private func requestHint() {
        guard !isCalculatingHint, gameManager.canUseHint else { return }

        isCalculatingHint = true
        HapticManager.shared.selection()

        // Run the solver on a background thread for larger search spaces
        DispatchQueue.global(qos: .userInteractive).async {
            let solver = KnuthSolver(tier: game.tier)
            let hint = solver.getHint(guessHistory: game.guessHistory)

            DispatchQueue.main.async {
                isCalculatingHint = false
                if let hint = hint {
                    // Consume a daily hint
                    gameManager.useHint()

                    currentHint = hint
                    withAnimation {
                        showingHint = true
                    }
                    HapticManager.shared.notification(.success)
                } else {
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }

    private func applyHint(_ hint: KnuthSolver.HintResult) {
        // Fill the current guess with the suggested colors
        for (index, color) in hint.suggestedGuess.enumerated() {
            game.setColor(at: index, color: color)
        }
        HapticManager.shared.pegPlaced()
        SoundManager.shared.pegPlaced()
    }
}

// MARK: - Hint Overlay View

struct HintOverlayView: View {
    let hint: KnuthSolver.HintResult
    let onApply: () -> Void
    let onDismiss: () -> Void

    @AppStorage("colorblindMode") private var colorblindMode = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.5), radius: 10)

                    Text("Suggested Guess")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                }

                // Suggested code display
                HStack(spacing: 12) {
                    ForEach(Array(hint.suggestedGuess.enumerated()), id: \.offset) { _, color in
                        ZStack {
                            Circle()
                                .fill(color.color)
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                )
                                .shadow(color: color.color.opacity(0.5), radius: 6, y: 2)

                            if colorblindMode {
                                Image(systemName: color.pattern)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Stats
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "number.circle.fill")
                            .foregroundColor(.blue)
                        Text("\(hint.remainingPossibilities) possible codes remaining")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    if hint.remainingPossibilities > 1 {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.green)
                            Text("Eliminates at least \(hint.guaranteedEliminationMin) possibilities")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    if hint.isOptimal {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Optimal guess")
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                        }
                    }
                }

                // Reasoning
                Text(hint.reasoning)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Buttons
                HStack(spacing: 16) {
                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                    }

                    Button(action: onApply) {
                        Label("Apply", systemImage: "checkmark.circle.fill")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.yellow)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Game Header

struct GameHeaderView: View {
    let title: String
    let attemptsRemaining: Int
    let maxAttempts: Int
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
            
            // Attempts indicator
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("\(attemptsRemaining)")
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

// MARK: - Guess Row

struct GuessRowView: View {
    let result: GuessResult
    let codeLength: Int
    let attemptNumber: Int
    let isRevealing: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Attempt number
            Text("\(attemptNumber)")
                .font(.caption.weight(.bold))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24)

            // Guess pegs
            HStack(spacing: 8) {
                ForEach(0..<codeLength, id: \.self) { index in
                    PegView(color: result.guess[index])
                }
            }

            Spacer()

            // Feedback pegs with animation
            FeedbackPegsView(feedback: result.feedback, shouldAnimate: isRevealing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Current Guess Row

struct CurrentGuessRowView: View {
    let currentGuess: [PegColor?]
    let codeLength: Int
    let attemptNumber: Int
    let selectedIndex: Int?
    var dragTargetIndex: Int? = nil
    let onPegTap: (Int) -> Void
    var onPegLongPress: ((Int) -> Void)? = nil
    var onDrop: ((Int, PegColor) -> Void)? = nil
    var onDropTargetChanged: ((Int?) -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Attempt number
            Text("\(attemptNumber)")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 24)

            // Guess pegs (tappable with long press and drop support)
            HStack(spacing: 8) {
                ForEach(0..<codeLength, id: \.self) { index in
                    DroppablePegSlot(
                        color: currentGuess[index],
                        isSelected: selectedIndex == index,
                        isDropTarget: dragTargetIndex == index,
                        onTap: { onPegTap(index) },
                        onLongPress: { onPegLongPress?(index) },
                        onDrop: { color in onDrop?(index, color) },
                        onDropTargetChanged: { isTarget in
                            onDropTargetChanged?(isTarget ? index : nil)
                        }
                    )
                }
            }

            Spacer()

            // Empty feedback area
            FeedbackPegsView(feedback: Array(repeating: .empty, count: codeLength))
                .opacity(0.3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Droppable Peg Slot

struct DroppablePegSlot: View {
    let color: PegColor?
    let isSelected: Bool
    let isDropTarget: Bool
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil
    var onDrop: ((PegColor) -> Void)? = nil
    var onDropTargetChanged: ((Bool) -> Void)? = nil

    @AppStorage("colorblindMode") private var colorblindMode = false

    var body: some View {
        Group {
            if let color = color {
                // Filled peg - can be dragged to reorder
                ZStack {
                    Circle()
                        .fill(color.color)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(strokeColor, lineWidth: strokeWidth)
                        )
                        .shadow(color: color.color.opacity(0.5), radius: isSelected || isDropTarget ? 8 : 4, y: 2)

                    if colorblindMode {
                        Image(systemName: color.pattern)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    }
                }
                .scaleEffect(scaleEffect)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDropTarget)
                .onTapGesture { onTap() }
                .onLongPressGesture(minimumDuration: 0.3, pressing: { isPressing in
                    if isPressing {
                        HapticManager.shared.longPressStart()
                    }
                }) {
                    HapticManager.shared.longPressEnd()
                    onLongPress?()
                }
                .draggable(color) {
                    // Drag preview for existing peg
                    ZStack {
                        Circle()
                            .fill(color.color)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                            )
                            .shadow(color: color.color.opacity(0.8), radius: 8, y: 4)

                        if colorblindMode {
                            Image(systemName: color.pattern)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            } else {
                // Empty slot
                Circle()
                    .stroke(strokeColor, lineWidth: 2)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(isSelected || isDropTarget ? 0.3 : 0.1))
                    )
                    .scaleEffect(scaleEffect)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDropTarget)
                    .onTapGesture { onTap() }
            }
        }
        .dropDestination(for: PegColor.self) { items, _ in
            guard let droppedColor = items.first else { return false }
            onDrop?(droppedColor)
            return true
        } isTargeted: { isTargeted in
            onDropTargetChanged?(isTargeted)
        }
    }

    private var strokeColor: Color {
        if isDropTarget {
            return Color.green
        } else if isSelected {
            return Color.white
        } else {
            return Color.white.opacity(0.3)
        }
    }

    private var strokeWidth: CGFloat {
        if isDropTarget {
            return 3
        } else if isSelected {
            return 3
        } else {
            return 2
        }
    }

    private var scaleEffect: CGFloat {
        if isDropTarget {
            return 1.15
        } else if isSelected {
            return 1.1
        } else {
            return 1.0
        }
    }
}

// MARK: - Empty Row

struct EmptyRowView: View {
    let codeLength: Int
    let attemptNumber: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(attemptNumber)")
                .font(.caption.weight(.bold))
                .foregroundColor(.white.opacity(0.3))
                .frame(width: 24)
            
            HStack(spacing: 8) {
                ForEach(0..<codeLength, id: \.self) { _ in
                    EmptyPegView(isSelected: false)
                        .opacity(0.5)
                }
            }
            
            Spacer()
            
            FeedbackPegsView(feedback: Array(repeating: .empty, count: codeLength))
                .opacity(0.2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Peg Views

struct PegView: View {
    let color: PegColor
    var isSelected: Bool = false
    @AppStorage("colorblindMode") private var colorblindMode = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.color)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.white : Color.white.opacity(0.3), lineWidth: isSelected ? 3 : 2)
                )
                .shadow(color: color.color.opacity(0.5), radius: isSelected ? 8 : 4, y: 2)

            // Colorblind pattern overlay
            if colorblindMode {
                Image(systemName: color.pattern)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

struct EmptyPegView: View {
    var isSelected: Bool = false
    
    var body: some View {
        Circle()
            .stroke(isSelected ? Color.white : Color.white.opacity(0.3), lineWidth: 2)
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(Color.white.opacity(isSelected ? 0.2 : 0.1))
            )
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Feedback Pegs

struct FeedbackPegsView: View {
    let feedback: [FeedbackPeg]
    var shouldAnimate: Bool = false

    @State private var revealedIndices: Set<Int> = []

    var body: some View {
        let gridSize = feedback.count <= 4 ? 2 : 3

        LazyVGrid(columns: Array(repeating: GridItem(.fixed(12), spacing: 4), count: gridSize), spacing: 4) {
            ForEach(0..<feedback.count, id: \.self) { index in
                Circle()
                    .fill(feedback[index].color)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                    .scaleEffect(shouldAnimate && revealedIndices.contains(index) ? 1 : (shouldAnimate ? 0 : 1))
                    .opacity(shouldAnimate && revealedIndices.contains(index) ? 1 : (shouldAnimate ? 0 : 1))
                    .animation(
                        shouldAnimate ? .spring(response: 0.4, dampingFraction: 0.6).delay(Double(index) * 0.1) : nil,
                        value: revealedIndices
                    )
            }
        }
        .frame(width: CGFloat(gridSize) * 16, height: CGFloat((feedback.count + gridSize - 1) / gridSize) * 16)
        .onAppear {
            if shouldAnimate {
                // Trigger reveal animation
                for i in 0..<feedback.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                        revealedIndices.insert(i)
                    }
                }
            }
        }
    }
}

// MARK: - Color Picker

struct ColorPickerView: View {
    let colors: [PegColor]
    let onColorSelected: (PegColor) -> Void
    var onDragStarted: (() -> Void)? = nil
    @AppStorage("colorblindMode") private var colorblindMode = false

    var body: some View {
        HStack(spacing: 12) {
            ForEach(colors) { color in
                DraggableColorPeg(
                    color: color,
                    colorblindMode: colorblindMode,
                    onTap: { onColorSelected(color) },
                    onDragStarted: onDragStarted
                )
            }
        }
    }
}

// MARK: - Draggable Color Peg

struct DraggableColorPeg: View {
    let color: PegColor
    let colorblindMode: Bool
    let onTap: () -> Void
    var onDragStarted: (() -> Void)? = nil

    @State private var isDragging = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.color)
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: color.color.opacity(0.5), radius: isDragging ? 8 : 4, y: 2)

            // Colorblind pattern overlay
            if colorblindMode {
                Image(systemName: color.pattern)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
        }
        .scaleEffect(isDragging ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
        .onTapGesture {
            onTap()
        }
        .draggable(color) {
            // Drag preview
            ZStack {
                Circle()
                    .fill(color.color)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: color.color.opacity(0.8), radius: 10, y: 4)

                if colorblindMode {
                    Image(systemName: color.pattern)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .onAppear {
                isDragging = true
                onDragStarted?()
                HapticManager.shared.impact(.medium)
            }
        }
        .onChange(of: isDragging) { _, newValue in
            if newValue == false {
                // Reset when drag ends
            }
        }
    }
}

#Preview {
    GameView(tier: .tutorial, level: GameLevel(id: 0, tier: .tutorial, levelInTier: 1, isUnlocked: true))
        .environmentObject(GameManager())
        .environmentObject(LivesManager.shared)
}
