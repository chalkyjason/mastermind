import Foundation
import SwiftUI

// MARK: - Binary Grid Game

/// Core game logic for Binary Grid (Takuzu/0h h1) puzzle
/// Rules:
/// 1. No three consecutive cells of the same color (row or column)
/// 2. Each row/column must have equal red and blue cells
/// 3. No two rows or columns can be identical
class BinaryGridGame: ObservableObject {
    @Published var grid: [[BinaryGridCell]]
    @Published var lockedCells: [[Bool]]
    @Published var gameState: BinaryGridState = .playing
    @Published var errorCells: Set<CellPosition> = []

    let difficulty: BinaryGridDifficulty
    let level: BinaryGridLevel?
    let gridSize: Int

    private var solution: [[BinaryGridCell]]
    private var startTime: Date?
    private var moveCount: Int = 0

    // MARK: - Initialization

    init(difficulty: BinaryGridDifficulty, level: BinaryGridLevel? = nil) {
        self.difficulty = difficulty
        self.level = level
        self.gridSize = difficulty.gridSize

        // Initialize empty grids
        let emptyGrid = Array(repeating: Array(repeating: BinaryGridCell.empty, count: difficulty.gridSize), count: difficulty.gridSize)
        self.grid = emptyGrid
        self.lockedCells = Array(repeating: Array(repeating: false, count: difficulty.gridSize), count: difficulty.gridSize)
        self.solution = emptyGrid

        // Generate puzzle
        generatePuzzle()
    }

    // MARK: - Puzzle Generation

    private func generatePuzzle() {
        let seed: UInt64
        if let level = level {
            seed = UInt64(level.id * 54321 + difficulty.rawValue * 1000)
        } else {
            seed = UInt64(Date().timeIntervalSince1970)
        }

        var rng = SeededRandomNumberGenerator(seed: seed)

        // Generate a valid complete solution
        solution = generateValidSolution(using: &rng)

        // Create puzzle by removing cells
        grid = solution
        lockedCells = Array(repeating: Array(repeating: true, count: gridSize), count: gridSize)

        // Remove cells to create puzzle (keep prefilledPercentage)
        let totalCells = gridSize * gridSize
        let cellsToRemove = Int(Double(totalCells) * (1.0 - difficulty.prefilledPercentage))

        var removedCount = 0
        var attempts = 0
        let maxAttempts = totalCells * 10

        while removedCount < cellsToRemove && attempts < maxAttempts {
            let row = Int.random(in: 0..<gridSize, using: &rng)
            let col = Int.random(in: 0..<gridSize, using: &rng)

            if lockedCells[row][col] {
                grid[row][col] = .empty
                lockedCells[row][col] = false
                removedCount += 1
            }
            attempts += 1
        }

        startTime = Date()
    }

    /// Generate a valid complete binary grid solution
    private func generateValidSolution(using rng: inout SeededRandomNumberGenerator) -> [[BinaryGridCell]] {
        var grid = Array(repeating: Array(repeating: BinaryGridCell.empty, count: gridSize), count: gridSize)

        // Use backtracking to fill the grid
        _ = fillGrid(&grid, row: 0, col: 0, using: &rng)

        return grid
    }

    private func fillGrid(_ grid: inout [[BinaryGridCell]], row: Int, col: Int, using rng: inout SeededRandomNumberGenerator) -> Bool {
        if row >= gridSize {
            return true // All cells filled
        }

        let nextRow = col + 1 >= gridSize ? row + 1 : row
        let nextCol = col + 1 >= gridSize ? 0 : col + 1

        // Try both colors in random order
        var colors: [BinaryGridCell] = [.red, .blue]
        colors.shuffle(using: &rng)

        for color in colors {
            grid[row][col] = color

            if isValidPlacement(grid, row: row, col: col) {
                if fillGrid(&grid, row: nextRow, col: nextCol, using: &rng) {
                    return true
                }
            }
        }

        grid[row][col] = .empty
        return false
    }

    /// Check if placing a cell is valid according to rules
    private func isValidPlacement(_ grid: [[BinaryGridCell]], row: Int, col: Int) -> Bool {
        let cell = grid[row][col]
        guard cell != .empty else { return true }

        // Rule 1: No three consecutive same colors in row
        if col >= 2 {
            if grid[row][col-1] == cell && grid[row][col-2] == cell {
                return false
            }
        }

        // Rule 1: No three consecutive same colors in column
        if row >= 2 {
            if grid[row-1][col] == cell && grid[row-2][col] == cell {
                return false
            }
        }

        // Rule 2: Check row count (only if row is complete up to this point for generation)
        let rowCells = grid[row].prefix(col + 1)
        let rowRedCount = rowCells.filter { $0 == .red }.count
        let rowBlueCount = rowCells.filter { $0 == .blue }.count
        let maxPerRow = gridSize / 2

        if rowRedCount > maxPerRow || rowBlueCount > maxPerRow {
            return false
        }

        // Rule 2: Check column count
        let colCells = (0...row).map { grid[$0][col] }
        let colRedCount = colCells.filter { $0 == .red }.count
        let colBlueCount = colCells.filter { $0 == .blue }.count

        if colRedCount > maxPerRow || colBlueCount > maxPerRow {
            return false
        }

        // Rule 3: Check for duplicate rows (only when row is complete)
        if col == gridSize - 1 && !grid[row].contains(.empty) {
            for r in 0..<row {
                if !grid[r].contains(.empty) && grid[r] == grid[row] {
                    return false
                }
            }
        }

        // Rule 3: Check for duplicate columns (only when column is complete)
        if row == gridSize - 1 {
            let currentCol = (0..<gridSize).map { grid[$0][col] }
            if !currentCol.contains(.empty) {
                for c in 0..<col {
                    let otherCol = (0..<gridSize).map { grid[$0][c] }
                    if !otherCol.contains(.empty) && otherCol == currentCol {
                        return false
                    }
                }
            }
        }

        return true
    }

    // MARK: - Gameplay

    func toggleCell(row: Int, col: Int) {
        guard gameState == .playing else { return }
        guard !lockedCells[row][col] else {
            HapticManager.shared.notification(.error)
            return
        }

        grid[row][col] = grid[row][col].next()
        moveCount += 1

        HapticManager.shared.selection()
        SoundManager.shared.pegPlaced()

        // Clear errors and revalidate
        errorCells.removeAll()
        validateGrid()

        // Check for win
        checkWinCondition()
    }

    func setCell(row: Int, col: Int, value: BinaryGridCell) {
        guard gameState == .playing else { return }
        guard !lockedCells[row][col] else { return }

        grid[row][col] = value
        moveCount += 1

        errorCells.removeAll()
        validateGrid()
        checkWinCondition()
    }

    // MARK: - Validation

    /// Validate current grid and mark error cells
    private func validateGrid() {
        var errors = Set<CellPosition>()

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if grid[row][col] != .empty {
                    // Check for three in a row (horizontal)
                    if let errorPositions = checkThreeInRow(row: row, col: col) {
                        errors.formUnion(errorPositions)
                    }

                    // Check for three in a row (vertical)
                    if let errorPositions = checkThreeInColumn(row: row, col: col) {
                        errors.formUnion(errorPositions)
                    }
                }
            }
        }

        // Check row counts
        for row in 0..<gridSize {
            let rowCells = grid[row]
            let redCount = rowCells.filter { $0 == .red }.count
            let blueCount = rowCells.filter { $0 == .blue }.count
            let maxCount = gridSize / 2

            if redCount > maxCount {
                for col in 0..<gridSize where grid[row][col] == .red {
                    errors.insert(CellPosition(row: row, col: col))
                }
            }
            if blueCount > maxCount {
                for col in 0..<gridSize where grid[row][col] == .blue {
                    errors.insert(CellPosition(row: row, col: col))
                }
            }
        }

        // Check column counts
        for col in 0..<gridSize {
            let colCells = (0..<gridSize).map { grid[$0][col] }
            let redCount = colCells.filter { $0 == .red }.count
            let blueCount = colCells.filter { $0 == .blue }.count
            let maxCount = gridSize / 2

            if redCount > maxCount {
                for row in 0..<gridSize where grid[row][col] == .red {
                    errors.insert(CellPosition(row: row, col: col))
                }
            }
            if blueCount > maxCount {
                for row in 0..<gridSize where grid[row][col] == .blue {
                    errors.insert(CellPosition(row: row, col: col))
                }
            }
        }

        // Check for duplicate rows
        for row1 in 0..<gridSize {
            if grid[row1].contains(.empty) { continue }
            for row2 in (row1 + 1)..<gridSize {
                if grid[row2].contains(.empty) { continue }
                if grid[row1] == grid[row2] {
                    for col in 0..<gridSize {
                        errors.insert(CellPosition(row: row1, col: col))
                        errors.insert(CellPosition(row: row2, col: col))
                    }
                }
            }
        }

        // Check for duplicate columns
        for col1 in 0..<gridSize {
            let column1 = (0..<gridSize).map { grid[$0][col1] }
            if column1.contains(.empty) { continue }
            for col2 in (col1 + 1)..<gridSize {
                let column2 = (0..<gridSize).map { grid[$0][col2] }
                if column2.contains(.empty) { continue }
                if column1 == column2 {
                    for row in 0..<gridSize {
                        errors.insert(CellPosition(row: row, col: col1))
                        errors.insert(CellPosition(row: row, col: col2))
                    }
                }
            }
        }

        errorCells = errors
    }

    private func checkThreeInRow(row: Int, col: Int) -> Set<CellPosition>? {
        let cell = grid[row][col]
        guard cell != .empty else { return nil }

        // Check left
        if col >= 2 && grid[row][col-1] == cell && grid[row][col-2] == cell {
            return [
                CellPosition(row: row, col: col),
                CellPosition(row: row, col: col-1),
                CellPosition(row: row, col: col-2)
            ]
        }

        // Check center
        if col >= 1 && col < gridSize - 1 && grid[row][col-1] == cell && grid[row][col+1] == cell {
            return [
                CellPosition(row: row, col: col-1),
                CellPosition(row: row, col: col),
                CellPosition(row: row, col: col+1)
            ]
        }

        // Check right
        if col < gridSize - 2 && grid[row][col+1] == cell && grid[row][col+2] == cell {
            return [
                CellPosition(row: row, col: col),
                CellPosition(row: row, col: col+1),
                CellPosition(row: row, col: col+2)
            ]
        }

        return nil
    }

    private func checkThreeInColumn(row: Int, col: Int) -> Set<CellPosition>? {
        let cell = grid[row][col]
        guard cell != .empty else { return nil }

        // Check above
        if row >= 2 && grid[row-1][col] == cell && grid[row-2][col] == cell {
            return [
                CellPosition(row: row, col: col),
                CellPosition(row: row-1, col: col),
                CellPosition(row: row-2, col: col)
            ]
        }

        // Check center
        if row >= 1 && row < gridSize - 1 && grid[row-1][col] == cell && grid[row+1][col] == cell {
            return [
                CellPosition(row: row-1, col: col),
                CellPosition(row: row, col: col),
                CellPosition(row: row+1, col: col)
            ]
        }

        // Check below
        if row < gridSize - 2 && grid[row+1][col] == cell && grid[row+2][col] == cell {
            return [
                CellPosition(row: row, col: col),
                CellPosition(row: row+1, col: col),
                CellPosition(row: row+2, col: col)
            ]
        }

        return nil
    }

    // MARK: - Win Condition

    private func checkWinCondition() {
        // Must have no empty cells
        for row in grid {
            if row.contains(.empty) { return }
        }

        // Must have no errors
        if !errorCells.isEmpty { return }

        // Grid is complete and valid - player wins!
        let elapsedTime = Date().timeIntervalSince(startTime ?? Date())
        let stars = BinaryGridLevel.calculateStars(time: elapsedTime, gridSize: gridSize)

        // Explicitly notify observers before state change
        objectWillChange.send()
        gameState = .won(time: elapsedTime, stars: stars)

        HapticManager.shared.correctGuess()
        SoundManager.shared.correctGuess()
    }

    // MARK: - Helper Properties

    var elapsedTime: TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    var progress: Double {
        let totalCells = gridSize * gridSize
        let filledCells = grid.flatMap { $0 }.filter { $0 != .empty }.count
        return Double(filledCells) / Double(totalCells)
    }

    var remainingCells: Int {
        grid.flatMap { $0 }.filter { $0 == .empty }.count
    }

    // MARK: - Actions

    func restart() {
        generatePuzzle()
        gameState = .playing
        errorCells.removeAll()
        moveCount = 0
    }

    func clearUserInput() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if !lockedCells[row][col] {
                    grid[row][col] = .empty
                }
            }
        }
        errorCells.removeAll()
        HapticManager.shared.impact(.medium)
    }
}

// MARK: - Supporting Types

struct CellPosition: Hashable {
    let row: Int
    let col: Int
}

enum BinaryGridState: Equatable {
    case playing
    case won(time: TimeInterval, stars: Int)
    case lost
    case paused
}
