import SwiftUI
import Combine

// MARK: - Flow Connect Game

class FlowConnectGame: ObservableObject {
    @Published private(set) var grid: [[FlowCell]]
    @Published private(set) var gameState: FlowConnectState = .playing
    @Published private(set) var moveCount: Int = 0
    @Published private(set) var flowColors: [FlowColor]

    let gridSize: Int
    let difficulty: FlowConnectDifficulty
    private let level: FlowConnectLevel?
    private var endpoints: [(FlowColor, GridPosition, GridPosition)] = []
    private var initialGrid: [[FlowCell]] = []

    // Current drawing state
    @Published var currentDrawingColor: FlowColor?
    @Published var currentPath: [GridPosition] = []

    init(difficulty: FlowConnectDifficulty, level: FlowConnectLevel? = nil) {
        self.difficulty = difficulty
        self.gridSize = difficulty.gridSize
        self.level = level
        self.flowColors = []
        self.grid = Array(repeating: Array(repeating: FlowCell(), count: difficulty.gridSize), count: difficulty.gridSize)

        generatePuzzle()
    }

    // MARK: - Puzzle Generation

    private func generatePuzzle() {
        let seed: UInt64
        if let level = level {
            seed = UInt64(level.id * 54321 + difficulty.gridSize * 1000)
        } else {
            seed = UInt64.random(in: 0...UInt64.max)
        }

        var rng = SeededRandomNumberGenerator(seed: seed)

        // Reset grid
        grid = Array(repeating: Array(repeating: FlowCell(), count: gridSize), count: gridSize)
        endpoints = []
        flowColors = []

        // Generate valid puzzle with paths
        generateValidPuzzle(using: &rng)

        // Store initial state
        initialGrid = grid.map { $0.map { $0 } }
    }

    private func generateValidPuzzle(using rng: inout SeededRandomNumberGenerator) {
        // Number of flows based on difficulty
        let flowCount = difficulty.flowCount
        let availableColors = FlowColor.allCases.shuffled(using: &rng)

        // Use a path-first generation: create paths then mark endpoints
        var usedCells = Set<GridPosition>()
        var generatedFlows: [(FlowColor, [GridPosition])] = []

        for i in 0..<flowCount {
            guard i < availableColors.count else { break }
            let color = availableColors[i]

            // Try to generate a valid path
            if let path = generatePath(avoiding: usedCells, minLength: difficulty.minPathLength, using: &rng) {
                generatedFlows.append((color, path))
                path.forEach { usedCells.insert($0) }
            }
        }

        // Place endpoints on grid
        for (color, path) in generatedFlows {
            guard path.count >= 2 else { continue }

            let start = path.first!
            let end = path.last!

            grid[start.row][start.col] = FlowCell(type: .endpoint, color: color)
            grid[end.row][end.col] = FlowCell(type: .endpoint, color: color)

            endpoints.append((color, start, end))
            flowColors.append(color)
        }
    }

    private func generatePath(avoiding usedCells: Set<GridPosition>, minLength: Int, using rng: inout SeededRandomNumberGenerator) -> [GridPosition]? {
        // Try multiple times to generate a valid path
        for _ in 0..<50 {
            // Pick random start
            let startRow = Int.random(in: 0..<gridSize, using: &rng)
            let startCol = Int.random(in: 0..<gridSize, using: &rng)
            let start = GridPosition(row: startRow, col: startCol)

            if usedCells.contains(start) { continue }

            // Random walk to create path
            var path = [start]
            var visited = usedCells
            visited.insert(start)

            let targetLength = Int.random(in: minLength...(minLength + 4), using: &rng)

            while path.count < targetLength {
                let current = path.last!
                let neighbors = getNeighbors(of: current)
                    .filter { !visited.contains($0) }
                    .shuffled(using: &rng)

                if let next = neighbors.first {
                    path.append(next)
                    visited.insert(next)
                } else {
                    break
                }
            }

            if path.count >= minLength {
                return path
            }
        }

        return nil
    }

    private func getNeighbors(of pos: GridPosition) -> [GridPosition] {
        let directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        return directions.compactMap { dr, dc in
            let newRow = pos.row + dr
            let newCol = pos.col + dc
            guard newRow >= 0 && newRow < gridSize && newCol >= 0 && newCol < gridSize else { return nil }
            return GridPosition(row: newRow, col: newCol)
        }
    }

    // MARK: - Drawing

    func startDrawing(at position: GridPosition) {
        guard gameState == .playing else { return }
        let cell = grid[position.row][position.col]

        // Can only start from an endpoint
        guard cell.type == .endpoint, let color = cell.color else { return }

        // Clear any existing path for this color
        clearPath(for: color)

        currentDrawingColor = color
        currentPath = [position]
        moveCount += 1
    }

    func continueDrawing(to position: GridPosition) {
        guard gameState == .playing else { return }
        guard let color = currentDrawingColor else { return }
        guard !currentPath.isEmpty else { return }

        let lastPos = currentPath.last!

        // Must be adjacent
        guard isAdjacent(lastPos, position) else { return }

        // Check if we're backtracking
        if currentPath.count >= 2 && currentPath[currentPath.count - 2] == position {
            // Remove last position (backtrack)
            currentPath.removeLast()
            return
        }

        // Can't cross existing paths (except our own starting endpoint)
        let targetCell = grid[position.row][position.col]

        if targetCell.type == .endpoint {
            // Can only end on matching color endpoint
            if targetCell.color == color && !currentPath.contains(position) {
                currentPath.append(position)
                // Path complete!
                commitPath()
            }
            return
        }

        if targetCell.type == .path {
            // Can't cross other paths
            if targetCell.color != color {
                return
            }
            // If it's our color, we might be reconnecting
        }

        // Can't revisit our own path
        if currentPath.contains(position) {
            return
        }

        currentPath.append(position)
    }

    func endDrawing() {
        guard currentDrawingColor != nil else { return }

        // Check if path connects two endpoints
        if currentPath.count >= 2 {
            let start = currentPath.first!
            let end = currentPath.last!

            let startCell = grid[start.row][start.col]
            let endCell = grid[end.row][end.col]

            if startCell.type == .endpoint && endCell.type == .endpoint &&
               startCell.color == endCell.color {
                commitPath()
            } else {
                // Incomplete path - clear it
                clearCurrentPath()
            }
        } else {
            clearCurrentPath()
        }

        currentDrawingColor = nil
        currentPath = []
    }

    private func commitPath() {
        guard let color = currentDrawingColor else { return }

        // Clear any existing path for this color first
        clearPath(for: color)

        // Draw the new path
        for pos in currentPath {
            let cell = grid[pos.row][pos.col]
            if cell.type != .endpoint {
                grid[pos.row][pos.col] = FlowCell(type: .path, color: color)
            }
        }

        currentDrawingColor = nil
        currentPath = []

        objectWillChange.send()
        checkWinCondition()
    }

    private func clearCurrentPath() {
        currentPath = []
    }

    func clearPath(for color: FlowColor) {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if grid[row][col].color == color && grid[row][col].type == .path {
                    grid[row][col] = FlowCell()
                }
            }
        }
    }

    private func isAdjacent(_ a: GridPosition, _ b: GridPosition) -> Bool {
        let rowDiff = abs(a.row - b.row)
        let colDiff = abs(a.col - b.col)
        return (rowDiff == 1 && colDiff == 0) || (rowDiff == 0 && colDiff == 1)
    }

    // MARK: - Win Condition

    private func checkWinCondition() {
        // Check all endpoints are connected
        for (color, start, end) in endpoints {
            if !isConnected(start, end, color: color) {
                return
            }
        }

        // Check if grid is filled (optional for some variants)
        let filledPercentage = calculateFilledPercentage()

        if filledPercentage >= 0.95 { // Allow small tolerance
            let stars = calculateStars()
            gameState = .won(moves: moveCount, stars: stars)
            HapticManager.shared.correctGuess()
            SoundManager.shared.correctGuess()
        }
    }

    private func isConnected(_ start: GridPosition, _ end: GridPosition, color: FlowColor) -> Bool {
        // BFS to check if start and end are connected via path of same color
        var visited = Set<GridPosition>()
        var queue = [start]
        visited.insert(start)

        while !queue.isEmpty {
            let current = queue.removeFirst()

            if current == end {
                return true
            }

            for neighbor in getNeighbors(of: current) {
                if visited.contains(neighbor) { continue }

                let cell = grid[neighbor.row][neighbor.col]
                if cell.color == color {
                    visited.insert(neighbor)
                    queue.append(neighbor)
                }
            }
        }

        return false
    }

    func calculateFilledPercentage() -> Double {
        var filled = 0
        for row in grid {
            for cell in row {
                if cell.type != .empty {
                    filled += 1
                }
            }
        }
        return Double(filled) / Double(gridSize * gridSize)
    }

    func connectedFlowCount() -> Int {
        var count = 0
        for (color, start, end) in endpoints {
            if isConnected(start, end, color: color) {
                count += 1
            }
        }
        return count
    }

    private func calculateStars() -> Int {
        let targetMoves = endpoints.count * 2
        let ratio = Double(moveCount) / Double(targetMoves)

        if ratio <= 1.0 {
            return 3
        } else if ratio <= 1.5 {
            return 2
        } else {
            return 1
        }
    }

    // MARK: - Actions

    func restart() {
        grid = initialGrid.map { $0.map { $0 } }
        // Clear all paths, keep only endpoints
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if grid[row][col].type == .path {
                    grid[row][col] = FlowCell()
                }
            }
        }
        moveCount = 0
        gameState = .playing
        currentDrawingColor = nil
        currentPath = []
    }

    func clearAll() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if grid[row][col].type == .path {
                    grid[row][col] = FlowCell()
                }
            }
        }
        currentDrawingColor = nil
        currentPath = []
    }
}

// MARK: - Supporting Types

struct FlowCell: Equatable {
    var type: FlowCellType = .empty
    var color: FlowColor?
}

enum FlowCellType: Equatable {
    case empty
    case endpoint
    case path
}

enum FlowColor: Int, CaseIterable, Codable {
    case red = 0
    case blue
    case green
    case yellow
    case orange
    case purple
    case cyan
    case pink
    case lime
    case maroon

    var color: Color {
        switch self {
        case .red: return Color("PegRed")
        case .blue: return Color("PegBlue")
        case .green: return Color("PegGreen")
        case .yellow: return Color("PegYellow")
        case .orange: return Color("PegOrange")
        case .purple: return Color("PegPurple")
        case .cyan: return Color("PegCyan")
        case .pink: return Color("PegPink")
        case .lime: return Color.green.opacity(0.7)
        case .maroon: return Color.red.opacity(0.6)
        }
    }
}

struct GridPosition: Hashable, Equatable {
    let row: Int
    let col: Int
}

enum FlowConnectState: Equatable {
    case playing
    case won(moves: Int, stars: Int)
    case paused
}
