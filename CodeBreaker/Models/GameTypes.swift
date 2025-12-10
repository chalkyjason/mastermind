import SwiftUI

// MARK: - Peg Colors

enum PegColor: String, CaseIterable, Codable, Identifiable {
    case red
    case blue
    case green
    case yellow
    case purple
    case orange
    case pink
    case cyan
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .red: return Color("PegRed")
        case .blue: return Color("PegBlue")
        case .green: return Color("PegGreen")
        case .yellow: return Color("PegYellow")
        case .purple: return Color("PegPurple")
        case .orange: return Color("PegOrange")
        case .pink: return Color("PegPink")
        case .cyan: return Color("PegCyan")
        }
    }
    
    var accessibilityLabel: String {
        rawValue.capitalized
    }
    
    // Colorblind-friendly patterns
    var pattern: String {
        switch self {
        case .red: return "circle.fill"
        case .blue: return "square.fill"
        case .green: return "triangle.fill"
        case .yellow: return "star.fill"
        case .purple: return "diamond.fill"
        case .orange: return "hexagon.fill"
        case .pink: return "heart.fill"
        case .cyan: return "pentagon.fill"
        }
    }
}

// MARK: - Feedback Peg

enum FeedbackPeg: Equatable {
    case black  // Correct color, correct position
    case white  // Correct color, wrong position
    case empty  // No match
    
    var color: Color {
        switch self {
        case .black: return .black
        case .white: return .white
        case .empty: return Color.gray.opacity(0.3)
        }
    }
}

// MARK: - Guess Result

struct GuessResult: Equatable {
    let guess: [PegColor]
    let feedback: [FeedbackPeg]
    
    var blackCount: Int {
        feedback.filter { $0 == .black }.count
    }
    
    var whiteCount: Int {
        feedback.filter { $0 == .white }.count
    }
    
    var isCorrect: Bool {
        feedback.allSatisfy { $0 == .black }
    }
}

// MARK: - Difficulty Level

enum DifficultyTier: Int, CaseIterable, Codable {
    case tutorial = 0
    case beginner = 1
    case intermediate = 2
    case advanced = 3
    case expert = 4
    case master = 5
    
    var name: String {
        switch self {
        case .tutorial: return "Tutorial"
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        case .master: return "Master"
        }
    }
    
    var codeLength: Int {
        switch self {
        case .tutorial: return 3
        case .beginner: return 4
        case .intermediate: return 4
        case .advanced: return 4
        case .expert: return 5
        case .master: return 5
        }
    }
    
    var colorCount: Int {
        switch self {
        case .tutorial: return 4
        case .beginner: return 5
        case .intermediate: return 6
        case .advanced: return 6
        case .expert: return 7
        case .master: return 8
        }
    }
    
    var maxAttempts: Int {
        switch self {
        case .tutorial: return 10
        case .beginner: return 10
        case .intermediate: return 8
        case .advanced: return 7
        case .expert: return 7
        case .master: return 6
        }
    }
    
    var allowDuplicates: Bool {
        switch self {
        case .tutorial, .beginner: return false
        default: return true
        }
    }
    
    var levelsCount: Int {
        switch self {
        case .tutorial: return 10
        case .beginner: return 30
        case .intermediate: return 50
        case .advanced: return 60
        case .expert: return 80
        case .master: return 100
        }
    }
    
    var iconName: String {
        switch self {
        case .tutorial: return "graduationcap.fill"
        case .beginner: return "leaf.fill"
        case .intermediate: return "flame.fill"
        case .advanced: return "bolt.fill"
        case .expert: return "crown.fill"
        case .master: return "sparkles"
        }
    }
    
    var color: Color {
        switch self {
        case .tutorial: return .green
        case .beginner: return .blue
        case .intermediate: return .orange
        case .advanced: return .red
        case .expert: return .purple
        case .master: return Color("AccentGold")
        }
    }
    
    var availableColors: [PegColor] {
        Array(PegColor.allCases.prefix(colorCount))
    }
}

// MARK: - Level

struct GameLevel: Identifiable, Codable {
    let id: Int
    let tier: DifficultyTier
    let levelInTier: Int
    var stars: Int = 0
    var isUnlocked: Bool = false
    var bestAttempts: Int?
    
    var displayName: String {
        "\(tier.name) \(levelInTier)"
    }
    
    // Calculate stars based on attempts used
    static func calculateStars(attempts: Int, maxAttempts: Int) -> Int {
        let percentage = Double(attempts) / Double(maxAttempts)
        if percentage <= 0.4 {
            return 3
        } else if percentage <= 0.7 {
            return 2
        } else {
            return 1
        }
    }
}

// MARK: - Game State

enum GameState: Equatable {
    case playing
    case won(attempts: Int, stars: Int)
    case lost
    case paused
}

// MARK: - Daily Challenge

struct DailyChallenge: Codable {
    let date: Date
    let secretCode: [PegColor]
    let tier: DifficultyTier
    var completed: Bool = false
    var attempts: Int?
    var stars: Int?
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    // Generate consistent daily challenge based on date
    static func forToday() -> DailyChallenge {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Use date as seed for consistent daily puzzle
        let components = calendar.dateComponents([.year, .month, .day], from: today)
        let seed = (components.year ?? 0) * 10000 + (components.month ?? 0) * 100 + (components.day ?? 0)
        
        var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
        
        // Daily challenge uses intermediate difficulty
        let tier = DifficultyTier.intermediate
        let colors = tier.availableColors
        var code: [PegColor] = []
        
        for _ in 0..<tier.codeLength {
            code.append(colors.randomElement(using: &rng)!)
        }
        
        return DailyChallenge(date: today, secretCode: code, tier: tier)
    }
}

// MARK: - Seeded Random Number Generator

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    var state: UInt64
    
    init(seed: UInt64) {
        state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
