import SwiftUI

struct GameView: View {
    @EnvironmentObject var gameManager: GameManager
    @StateObject private var game: MastermindGame
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingColorPicker = false
    @State private var selectedPegIndex: Int?
    @State private var showingWinSheet = false
    @State private var showingLoseSheet = false
    @State private var animatingFeedback = false
    @State private var revealedPegs: Set<Int> = []
    
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
                    onPause: { dismiss() }
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
                                    isRevealing: false
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
                                    onPegTap: { index in
                                        selectedPegIndex = index
                                        showingColorPicker = true
                                        HapticManager.shared.selection()
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
                                    
                                    // Auto-advance to next empty slot
                                    advanceToNextEmptySlot(from: index)
                                }
                            }
                        )
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                game.clearCurrentGuess()
                                selectedPegIndex = 0
                                HapticManager.shared.impact(.light)
                            }) {
                                Label("Clear", systemImage: "xmark.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 20)
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
            
            // Win/Lose overlays
            if showingWinSheet {
                WinOverlayView(
                    attempts: game.guessHistory.count,
                    maxAttempts: game.maxAttempts,
                    secretCode: game.secretCode,
                    isDaily: isDaily,
                    onContinue: handleWinContinue,
                    onReplay: handleReplay
                )
                .transition(.opacity)
            }
            
            if showingLoseSheet {
                LoseOverlayView(
                    secretCode: game.secretCode,
                    onRetry: handleReplay,
                    onQuit: { dismiss() }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showingWinSheet = true
                }
            }
            
        case .lost:
            HapticManager.shared.gameLost()
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
    
    private func handleReplay() {
        showingWinSheet = false
        showingLoseSheet = false
        game.restart()
        selectedPegIndex = 0
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
            
            // Feedback pegs
            FeedbackPegsView(feedback: result.feedback)
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
    let onPegTap: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Attempt number
            Text("\(attemptNumber)")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 24)
            
            // Guess pegs (tappable)
            HStack(spacing: 8) {
                ForEach(0..<codeLength, id: \.self) { index in
                    Button(action: { onPegTap(index) }) {
                        if let color = currentGuess[index] {
                            PegView(color: color, isSelected: selectedIndex == index)
                        } else {
                            EmptyPegView(isSelected: selectedIndex == index)
                        }
                    }
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
            }
        }
        .frame(width: CGFloat(gridSize) * 16, height: CGFloat((feedback.count + gridSize - 1) / gridSize) * 16)
    }
}

// MARK: - Color Picker

struct ColorPickerView: View {
    let colors: [PegColor]
    let onColorSelected: (PegColor) -> Void
    @AppStorage("colorblindMode") private var colorblindMode = false

    var body: some View {
        HStack(spacing: 12) {
            ForEach(colors) { color in
                Button(action: { onColorSelected(color) }) {
                    ZStack {
                        Circle()
                            .fill(color.color)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                            .shadow(color: color.color.opacity(0.5), radius: 4, y: 2)

                        // Colorblind pattern overlay
                        if colorblindMode {
                            Image(systemName: color.pattern)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}

#Preview {
    GameView(tier: .tutorial, level: GameLevel(id: 0, tier: .tutorial, levelInTier: 1, isUnlocked: true))
        .environmentObject(GameManager())
}
