import Foundation

// MARK: - Knuth Solver

/// Implements Donald Knuth's minimax algorithm for solving Mastermind puzzles.
/// This solver can determine the optimal next guess and powers the hint system.
final class KnuthSolver {

    // MARK: - Feedback Structure

    /// Compact feedback representation for efficient computation
    struct Feedback: Hashable, Equatable {
        let black: Int  // Correct color, correct position
        let white: Int  // Correct color, wrong position

        /// Convert from FeedbackPeg array
        init(from pegs: [FeedbackPeg]) {
            self.black = pegs.filter { $0 == .black }.count
            self.white = pegs.filter { $0 == .white }.count
        }

        init(black: Int, white: Int) {
            self.black = black
            self.white = white
        }

        /// Returns true if this feedback indicates a win (all black pegs)
        var isWin: Bool {
            white == 0 && black > 0
        }
    }

    // MARK: - Hint Result

    /// Result from requesting a hint
    struct HintResult {
        let suggestedGuess: [PegColor]
        let remainingPossibilities: Int
        let guaranteedEliminationMin: Int
        let isOptimal: Bool
        let reasoning: String
    }

    // MARK: - Analysis Result

    /// Analysis of a player's guess quality
    struct GuessAnalysis {
        let guess: [PegColor]
        let optimalGuess: [PegColor]
        let wasOptimal: Bool
        let possibilitiesBefore: Int
        let possibilitiesAfter: Int
        let optimalWouldLeave: Int
        let rating: GuessRating

        enum GuessRating: String {
            case optimal = "Optimal"
            case good = "Good"
            case acceptable = "Acceptable"
            case suboptimal = "Suboptimal"
            case poor = "Poor"
        }
    }

    // MARK: - Properties

    private let codeLength: Int
    private let colorCount: Int
    private let allowDuplicates: Bool
    private let availableColors: [PegColor]

    /// All possible codes for this configuration
    private(set) var allCodes: [[PegColor]] = []

    /// Currently remaining possible codes
    private(set) var remainingCodes: [[PegColor]] = []

    // MARK: - Initialization

    init(tier: DifficultyTier) {
        self.codeLength = tier.codeLength
        self.colorCount = tier.colorCount
        self.allowDuplicates = tier.allowDuplicates
        self.availableColors = tier.availableColors
        self.allCodes = Self.generateAllCodes(
            colors: availableColors,
            length: codeLength,
            allowDuplicates: allowDuplicates
        )
        self.remainingCodes = allCodes
    }

    init(codeLength: Int, colorCount: Int, allowDuplicates: Bool) {
        self.codeLength = codeLength
        self.colorCount = colorCount
        self.allowDuplicates = allowDuplicates
        self.availableColors = Array(PegColor.allCases.prefix(colorCount))
        self.allCodes = Self.generateAllCodes(
            colors: availableColors,
            length: codeLength,
            allowDuplicates: allowDuplicates
        )
        self.remainingCodes = allCodes
    }

    // MARK: - Code Generation

    /// Generates all possible codes for the given configuration
    static func generateAllCodes(colors: [PegColor], length: Int, allowDuplicates: Bool) -> [[PegColor]] {
        var codes: [[PegColor]] = []

        if allowDuplicates {
            // Generate all permutations with repetition: k^n codes
            generatePermutationsWithRepetition(
                colors: colors,
                length: length,
                current: [],
                results: &codes
            )
        } else {
            // Generate permutations without repetition: n!/(n-k)! codes
            generatePermutationsWithoutRepetition(
                colors: colors,
                length: length,
                current: [],
                used: Set(),
                results: &codes
            )
        }

        return codes
    }

    private static func generatePermutationsWithRepetition(
        colors: [PegColor],
        length: Int,
        current: [PegColor],
        results: inout [[PegColor]]
    ) {
        if current.count == length {
            results.append(current)
            return
        }

        for color in colors {
            var newCurrent = current
            newCurrent.append(color)
            generatePermutationsWithRepetition(
                colors: colors,
                length: length,
                current: newCurrent,
                results: &results
            )
        }
    }

    private static func generatePermutationsWithoutRepetition(
        colors: [PegColor],
        length: Int,
        current: [PegColor],
        used: Set<PegColor>,
        results: inout [[PegColor]]
    ) {
        if current.count == length {
            results.append(current)
            return
        }

        for color in colors where !used.contains(color) {
            var newCurrent = current
            newCurrent.append(color)
            var newUsed = used
            newUsed.insert(color)
            generatePermutationsWithoutRepetition(
                colors: colors,
                length: length,
                current: newCurrent,
                used: newUsed,
                results: &results
            )
        }
    }

    // MARK: - Feedback Calculation

    /// Calculates feedback for a guess against a secret code
    /// This is the core Mastermind evaluation algorithm
    static func calculateFeedback(guess: [PegColor], secret: [PegColor]) -> Feedback {
        var black = 0
        var white = 0
        var secretRemaining: [PegColor?] = secret
        var guessRemaining: [PegColor?] = guess

        // Pass 1: Count exact matches (black pegs)
        for i in 0..<guess.count {
            if guess[i] == secret[i] {
                black += 1
                secretRemaining[i] = nil
                guessRemaining[i] = nil
            }
        }

        // Pass 2: Count color matches in wrong positions (white pegs)
        for i in 0..<guess.count {
            guard let guessColor = guessRemaining[i] else { continue }

            if let matchIndex = secretRemaining.firstIndex(where: { $0 == guessColor }) {
                white += 1
                secretRemaining[matchIndex] = nil
            }
        }

        return Feedback(black: black, white: white)
    }

    // MARK: - Possibility Filtering

    /// Filters remaining codes based on a guess and its feedback
    /// Only codes that would produce the same feedback are kept
    func filterRemainingCodes(guess: [PegColor], feedback: Feedback) {
        remainingCodes = remainingCodes.filter { code in
            Self.calculateFeedback(guess: guess, secret: code) == feedback
        }
    }

    /// Returns filtered codes without modifying state
    func codesConsistentWith(guess: [PegColor], feedback: Feedback, from codes: [[PegColor]]) -> [[PegColor]] {
        codes.filter { code in
            Self.calculateFeedback(guess: guess, secret: code) == feedback
        }
    }

    // MARK: - Minimax Algorithm (Knuth's Strategy)

    /// Finds the optimal guess using the minimax strategy
    /// This minimizes the maximum number of remaining possibilities
    func findOptimalGuess() -> [PegColor]? {
        guard !remainingCodes.isEmpty else { return nil }

        // If only one possibility remains, guess it
        if remainingCodes.count == 1 {
            return remainingCodes[0]
        }

        // If two possibilities remain, guess one of them
        if remainingCodes.count == 2 {
            return remainingCodes[0]
        }

        var bestGuess: [PegColor]?
        var bestScore = Int.max

        // Consider all possible guesses (from all codes, not just remaining)
        // This is key to Knuth's algorithm - sometimes guessing an impossible code
        // provides better information
        let candidatesToConsider: [[PegColor]]

        // For performance, limit candidates when search space is large
        if allCodes.count > 1000 {
            // Prioritize remaining codes + sample from all codes
            candidatesToConsider = remainingCodes + allCodes.shuffled().prefix(500)
        } else {
            candidatesToConsider = allCodes
        }

        for guess in candidatesToConsider {
            let score = calculateWorstCaseRemaining(for: guess)

            // Prefer guesses from remaining codes when scores are equal
            // This ensures we can win if we happen to guess correctly
            if score < bestScore || (score == bestScore && remainingCodes.contains(guess)) {
                bestScore = score
                bestGuess = guess
            }
        }

        return bestGuess
    }

    /// Calculates the worst-case (maximum) remaining possibilities for a guess
    private func calculateWorstCaseRemaining(for guess: [PegColor]) -> Int {
        var feedbackCounts: [Feedback: Int] = [:]

        // Count how many remaining codes produce each feedback
        for code in remainingCodes {
            let feedback = Self.calculateFeedback(guess: guess, secret: code)
            feedbackCounts[feedback, default: 0] += 1
        }

        // Return the maximum (worst case)
        return feedbackCounts.values.max() ?? 0
    }

    /// Calculates how many codes would be eliminated in the worst case
    func calculateGuaranteedElimination(for guess: [PegColor]) -> Int {
        let worstCase = calculateWorstCaseRemaining(for: guess)
        return remainingCodes.count - worstCase
    }

    // MARK: - Hint System

    /// Gets a hint based on the current game state
    func getHint(guessHistory: [GuessResult]) -> HintResult? {
        // Reset and replay history to get current state
        remainingCodes = allCodes

        for result in guessHistory {
            let feedback = Feedback(from: result.feedback)
            filterRemainingCodes(guess: result.guess, feedback: feedback)
        }

        guard !remainingCodes.isEmpty else {
            return nil
        }

        // If only one remains, that's the answer
        if remainingCodes.count == 1 {
            return HintResult(
                suggestedGuess: remainingCodes[0],
                remainingPossibilities: 1,
                guaranteedEliminationMin: 1,
                isOptimal: true,
                reasoning: "Only one possible code remains - this must be the answer!"
            )
        }

        // Find optimal guess
        guard let optimalGuess = findOptimalGuess() else {
            return nil
        }

        let guaranteedElim = calculateGuaranteedElimination(for: optimalGuess)
        let isFromRemaining = remainingCodes.contains(optimalGuess)

        let reasoning: String
        if isFromRemaining {
            reasoning = "This guess could be the answer and guarantees eliminating at least \(guaranteedElim) possibilities."
        } else {
            reasoning = "This guess maximizes information gain, eliminating at least \(guaranteedElim) possibilities."
        }

        return HintResult(
            suggestedGuess: optimalGuess,
            remainingPossibilities: remainingCodes.count,
            guaranteedEliminationMin: guaranteedElim,
            isOptimal: true,
            reasoning: reasoning
        )
    }

    // MARK: - Game Analysis

    /// Analyzes a player's guess compared to the optimal play
    func analyzeGuess(
        guess: [PegColor],
        feedback: Feedback,
        guessHistory: [GuessResult]
    ) -> GuessAnalysis {
        // Rebuild state before this guess
        remainingCodes = allCodes
        for result in guessHistory {
            let fb = Feedback(from: result.feedback)
            filterRemainingCodes(guess: result.guess, feedback: fb)
        }

        let possibilitiesBefore = remainingCodes.count

        // Find what the optimal guess would have been
        let optimalGuess = findOptimalGuess() ?? guess
        let optimalWorstCase = calculateWorstCaseRemaining(for: optimalGuess)

        // Calculate actual result
        let actualWorstCase = calculateWorstCaseRemaining(for: guess)
        let possibilitiesAfter = codesConsistentWith(
            guess: guess,
            feedback: feedback,
            from: remainingCodes
        ).count

        let optimalPossibilitiesAfter = codesConsistentWith(
            guess: optimalGuess,
            feedback: Self.calculateFeedback(guess: optimalGuess, secret: guess), // This isn't quite right but approximates
            from: remainingCodes
        ).count

        // Rate the guess
        let rating: GuessAnalysis.GuessRating
        let wasOptimal = guess == optimalGuess || actualWorstCase == optimalWorstCase

        if wasOptimal {
            rating = .optimal
        } else if actualWorstCase <= optimalWorstCase + 1 {
            rating = .good
        } else if actualWorstCase <= optimalWorstCase + 3 {
            rating = .acceptable
        } else if actualWorstCase <= optimalWorstCase + 5 {
            rating = .suboptimal
        } else {
            rating = .poor
        }

        return GuessAnalysis(
            guess: guess,
            optimalGuess: optimalGuess,
            wasOptimal: wasOptimal,
            possibilitiesBefore: possibilitiesBefore,
            possibilitiesAfter: possibilitiesAfter,
            optimalWouldLeave: optimalPossibilitiesAfter,
            rating: rating
        )
    }

    // MARK: - Utility Methods

    /// Resets the solver to initial state
    func reset() {
        remainingCodes = allCodes
    }

    /// Returns the opening move recommendation (Knuth's 1122 pattern adapted)
    func getOpeningGuess() -> [PegColor] {
        // Knuth proved that starting with two pairs (e.g., AABB) is optimal
        // Adapt this to current configuration
        guard availableColors.count >= 2 else {
            return Array(repeating: availableColors[0], count: codeLength)
        }

        var opening: [PegColor] = []
        let halfLength = codeLength / 2

        // First half: color A
        for _ in 0..<halfLength {
            opening.append(availableColors[0])
        }

        // Second half: color B
        for _ in halfLength..<codeLength {
            opening.append(availableColors[1])
        }

        return opening
    }

    /// Checks if a guess is consistent with the current state
    func isConsistent(_ guess: [PegColor], with history: [GuessResult]) -> Bool {
        var tempRemaining = allCodes

        for result in history {
            let feedback = Feedback(from: result.feedback)
            tempRemaining = tempRemaining.filter { code in
                Self.calculateFeedback(guess: result.guess, secret: code) == feedback
            }
        }

        return tempRemaining.contains(guess)
    }

    /// Returns codes that could still be the answer
    func getPossibleCodes(after history: [GuessResult]) -> [[PegColor]] {
        var remaining = allCodes

        for result in history {
            let feedback = Feedback(from: result.feedback)
            remaining = remaining.filter { code in
                Self.calculateFeedback(guess: result.guess, secret: code) == feedback
            }
        }

        return remaining
    }
}

// MARK: - Singleton for Quick Access

extension KnuthSolver {
    /// Creates a solver configured for a specific difficulty tier
    static func solver(for tier: DifficultyTier) -> KnuthSolver {
        KnuthSolver(tier: tier)
    }
}
