import Foundation

// MARK: - Mastermind Game

class MastermindGame: ObservableObject {
    @Published private(set) var secretCode: [PegColor]
    @Published private(set) var guessHistory: [GuessResult] = []
    @Published var currentGuess: [PegColor?]
    @Published private(set) var gameState: GameState = .playing
    
    let tier: DifficultyTier
    let level: GameLevel?
    
    var codeLength: Int { tier.codeLength }
    var maxAttempts: Int { tier.maxAttempts }
    var availableColors: [PegColor] { tier.availableColors }
    var attemptsRemaining: Int { maxAttempts - guessHistory.count }
    var currentAttempt: Int { guessHistory.count + 1 }
    
    var isGuessComplete: Bool {
        currentGuess.allSatisfy { $0 != nil }
    }
    
    // MARK: - Initialization
    
    init(tier: DifficultyTier, level: GameLevel? = nil, customCode: [PegColor]? = nil) {
        self.tier = tier
        self.level = level
        self.currentGuess = Array(repeating: nil, count: tier.codeLength)
        
        if let code = customCode {
            self.secretCode = code
        } else {
            self.secretCode = Self.generateSecretCode(tier: tier, levelSeed: level?.id)
        }
    }
    
    // MARK: - Code Generation
    
    static func generateSecretCode(tier: DifficultyTier, levelSeed: Int? = nil) -> [PegColor] {
        let colors = tier.availableColors
        var code: [PegColor] = []
        
        if let seed = levelSeed {
            // Use level ID as seed for consistent puzzles
            var rng = SeededRandomNumberGenerator(seed: UInt64(seed * 12345))
            
            if tier.allowDuplicates {
                for _ in 0..<tier.codeLength {
                    guard let color = colors.randomElement(using: &rng) else {
                        fatalError("Tier must have available colors")
                    }
                    code.append(color)
                }
            } else {
                var available = colors.shuffled(using: &rng)
                for _ in 0..<tier.codeLength {
                    code.append(available.removeFirst())
                }
            }
        } else {
            // Random code
            if tier.allowDuplicates {
                for _ in 0..<tier.codeLength {
                    guard let color = colors.randomElement() else {
                        fatalError("Tier must have available colors")
                    }
                    code.append(color)
                }
            } else {
                var available = colors.shuffled()
                for _ in 0..<tier.codeLength {
                    code.append(available.removeFirst())
                }
            }
        }
        
        return code
    }
    
    // MARK: - Gameplay
    
    func setColor(at index: Int, color: PegColor) {
        guard index >= 0 && index < codeLength else { return }
        guard gameState == .playing else { return }
        
        currentGuess[index] = color
    }
    
    func clearPosition(at index: Int) {
        guard index >= 0 && index < codeLength else { return }
        guard gameState == .playing else { return }
        
        currentGuess[index] = nil
    }
    
    func clearCurrentGuess() {
        currentGuess = Array(repeating: nil, count: codeLength)
    }
    
    func submitGuess() -> GuessResult? {
        guard isGuessComplete else { return nil }
        guard gameState == .playing else { return nil }
        
        let guess = currentGuess.compactMap { $0 }
        let feedback = calculateFeedback(guess: guess)
        let result = GuessResult(guess: guess, feedback: feedback)
        
        guessHistory.append(result)
        
        // Check win/loss conditions
        if result.isCorrect {
            let stars = GameLevel.calculateStars(attempts: guessHistory.count, maxAttempts: maxAttempts)
            gameState = .won(attempts: guessHistory.count, stars: stars)
        } else if guessHistory.count >= maxAttempts {
            gameState = .lost
        }
        
        // Clear for next guess
        clearCurrentGuess()
        
        return result
    }
    
    // MARK: - Feedback Calculation (Core Mastermind Algorithm)
    
    func calculateFeedback(guess: [PegColor]) -> [FeedbackPeg] {
        var feedback: [FeedbackPeg] = []
        var secretRemaining: [PegColor?] = secretCode.map { $0 }
        var guessRemaining: [PegColor?] = guess.map { $0 }
        
        // Step 1: Find exact matches (black pegs)
        for i in 0..<codeLength {
            if guess[i] == secretCode[i] {
                feedback.append(.black)
                secretRemaining[i] = nil
                guessRemaining[i] = nil
            }
        }
        
        // Step 2: Find color matches in wrong positions (white pegs)
        for i in 0..<codeLength {
            guard let guessColor = guessRemaining[i] else { continue }
            
            if let matchIndex = secretRemaining.firstIndex(where: { $0 == guessColor }) {
                feedback.append(.white)
                secretRemaining[matchIndex] = nil
            }
        }
        
        // Step 3: Fill remaining with empty
        while feedback.count < codeLength {
            feedback.append(.empty)
        }
        
        // Sort feedback: black first, then white, then empty
        feedback.sort { peg1, peg2 in
            let order: (FeedbackPeg) -> Int = { peg in
                switch peg {
                case .black: return 0
                case .white: return 1
                case .empty: return 2
                }
            }
            return order(peg1) < order(peg2)
        }
        
        return feedback
    }
    
    // MARK: - Game Control
    
    func restart() {
        guessHistory = []
        currentGuess = Array(repeating: nil, count: codeLength)
        gameState = .playing
        
        // Generate new code (unless it's a level with fixed code)
        if level == nil {
            secretCode = Self.generateSecretCode(tier: tier, levelSeed: nil)
        }
    }
    
    func pause() {
        if gameState == .playing {
            gameState = .paused
        }
    }
    
    func resume() {
        if gameState == .paused {
            gameState = .playing
        }
    }
}

// MARK: - Random Element with Generator

extension Array {
    func randomElement<T: RandomNumberGenerator>(using generator: inout T) -> Element? {
        guard !isEmpty else { return nil }
        let index = Int.random(in: 0..<count, using: &generator)
        return self[index]
    }
    
    func shuffled<T: RandomNumberGenerator>(using generator: inout T) -> [Element] {
        var result = self
        for i in stride(from: count - 1, through: 1, by: -1) {
            let j = Int.random(in: 0...i, using: &generator)
            result.swapAt(i, j)
        }
        return result
    }
}
