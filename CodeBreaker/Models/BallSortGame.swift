import Foundation
import SwiftUI

// MARK: - Ball Sort Game

class BallSortGame: ObservableObject {
    @Published private(set) var tubes: [[PegColor]]
    @Published private(set) var selectedTubeIndex: Int?
    @Published private(set) var moveHistory: [BallSortMove] = []
    @Published private(set) var gameState: BallSortGameState = .playing
    @Published private(set) var moveCount: Int = 0

    let difficulty: BallSortDifficulty
    let level: BallSortLevel?
    let tubeCapacity: Int = 4

    var numberOfTubes: Int { tubes.count }
    var numberOfColors: Int { difficulty.colorCount }

    var canUndo: Bool {
        !moveHistory.isEmpty && gameState == .playing
    }

    var isSolved: Bool {
        tubes.allSatisfy { tube in
            tube.isEmpty || (tube.count == tubeCapacity && tube.allSatisfy { $0 == tube.first })
        }
    }

    // MARK: - Initialization

    init(difficulty: BallSortDifficulty, level: BallSortLevel? = nil) {
        self.difficulty = difficulty
        self.level = level
        self.tubes = []
        self.tubes = Self.generatePuzzle(difficulty: difficulty, levelSeed: level?.id)
    }

    // MARK: - Puzzle Generation

    static func generatePuzzle(difficulty: BallSortDifficulty, levelSeed: Int? = nil) -> [[PegColor]] {
        let colorCount = difficulty.colorCount
        let emptyTubes = difficulty.emptyTubes
        let tubeCapacity = 4
        let totalTubes = colorCount + emptyTubes

        // Get available colors
        let availableColors = Array(PegColor.allCases.prefix(colorCount))

        // Create all balls (4 of each color)
        var allBalls: [PegColor] = []
        for color in availableColors {
            for _ in 0..<tubeCapacity {
                allBalls.append(color)
            }
        }

        // Shuffle balls with seed if provided
        if let seed = levelSeed {
            var rng = SeededRandomNumberGenerator(seed: UInt64(seed * 54321))
            allBalls = allBalls.shuffled(using: &rng)

            // Keep shuffling until we get a valid puzzle (not already solved)
            var attempts = 0
            while attempts < 100 {
                var testTubes: [[PegColor]] = []
                var ballIndex = 0

                for i in 0..<totalTubes {
                    if i < colorCount {
                        var tube: [PegColor] = []
                        for _ in 0..<tubeCapacity {
                            tube.append(allBalls[ballIndex])
                            ballIndex += 1
                        }
                        testTubes.append(tube)
                    } else {
                        testTubes.append([])
                    }
                }

                // Check if puzzle is not already solved
                let isSolved = testTubes.allSatisfy { tube in
                    tube.isEmpty || tube.allSatisfy { $0 == tube.first }
                }

                if !isSolved {
                    return testTubes
                }

                // Reshuffle and try again
                allBalls = allBalls.shuffled(using: &rng)
                attempts += 1
            }
        } else {
            allBalls.shuffle()
        }

        // Distribute balls into tubes
        var tubes: [[PegColor]] = []
        var ballIndex = 0

        for i in 0..<totalTubes {
            if i < colorCount {
                var tube: [PegColor] = []
                for _ in 0..<tubeCapacity {
                    tube.append(allBalls[ballIndex])
                    ballIndex += 1
                }
                tubes.append(tube)
            } else {
                // Empty tube
                tubes.append([])
            }
        }

        return tubes
    }

    // MARK: - Gameplay

    func selectTube(at index: Int) {
        guard index >= 0 && index < tubes.count else { return }
        guard gameState == .playing else { return }

        if let selected = selectedTubeIndex {
            // Already have a selection - try to move
            if selected == index {
                // Deselect
                selectedTubeIndex = nil
            } else if canMove(from: selected, to: index) {
                // Perform move
                performMove(from: selected, to: index)
                selectedTubeIndex = nil
            } else if !tubes[index].isEmpty {
                // Can't move there, select the new tube instead
                selectedTubeIndex = index
            } else {
                // Invalid move to empty tube (no ball selected)
                selectedTubeIndex = nil
            }
        } else {
            // No selection yet
            if !tubes[index].isEmpty {
                selectedTubeIndex = index
            }
        }
    }

    func deselectTube() {
        selectedTubeIndex = nil
    }

    func canMove(from sourceIndex: Int, to destIndex: Int) -> Bool {
        guard sourceIndex != destIndex else { return false }
        guard sourceIndex >= 0 && sourceIndex < tubes.count else { return false }
        guard destIndex >= 0 && destIndex < tubes.count else { return false }

        let sourceTube = tubes[sourceIndex]
        let destTube = tubes[destIndex]

        // Source must have balls
        guard let topBall = sourceTube.last else { return false }

        // Destination must have space
        guard destTube.count < tubeCapacity else { return false }

        // Destination must be empty or have matching color on top
        if let destTop = destTube.last {
            return destTop == topBall
        }

        return true
    }

    private func performMove(from sourceIndex: Int, to destIndex: Int) {
        guard canMove(from: sourceIndex, to: destIndex) else { return }

        // Count consecutive balls of same color at top of source
        let sourceTube = tubes[sourceIndex]
        guard let topColor = sourceTube.last else { return }

        var ballsToMove = 0
        for i in stride(from: sourceTube.count - 1, through: 0, by: -1) {
            if sourceTube[i] == topColor {
                ballsToMove += 1
            } else {
                break
            }
        }

        // Calculate how many can fit in destination
        let destSpace = tubeCapacity - tubes[destIndex].count
        let actualMoveCount = min(ballsToMove, destSpace)

        // Record move for undo
        let move = BallSortMove(
            from: sourceIndex,
            to: destIndex,
            ballCount: actualMoveCount,
            color: topColor
        )
        moveHistory.append(move)

        // Perform the move
        for _ in 0..<actualMoveCount {
            if let ball = tubes[sourceIndex].popLast() {
                tubes[destIndex].append(ball)
            }
        }

        moveCount += 1

        // Check for win
        if isSolved {
            let stars = BallSortLevel.calculateStars(moves: moveCount, minMoves: difficulty.targetMoves)
            gameState = .won(moves: moveCount, stars: stars)
        }
    }

    func undo() {
        guard canUndo else { return }
        guard let lastMove = moveHistory.popLast() else { return }

        // Reverse the move
        for _ in 0..<lastMove.ballCount {
            if let ball = tubes[lastMove.to].popLast() {
                tubes[lastMove.from].append(ball)
            }
        }

        moveCount -= 1
        selectedTubeIndex = nil
    }

    func restart() {
        tubes = Self.generatePuzzle(difficulty: difficulty, levelSeed: level?.id)
        selectedTubeIndex = nil
        moveHistory = []
        moveCount = 0
        gameState = .playing
    }

    // MARK: - Helper Methods

    func topBall(in tubeIndex: Int) -> PegColor? {
        guard tubeIndex >= 0 && tubeIndex < tubes.count else { return nil }
        return tubes[tubeIndex].last
    }

    func isTubeComplete(_ tubeIndex: Int) -> Bool {
        guard tubeIndex >= 0 && tubeIndex < tubes.count else { return false }
        let tube = tubes[tubeIndex]
        return tube.count == tubeCapacity && tube.allSatisfy { $0 == tube.first }
    }

    func isTubeEmpty(_ tubeIndex: Int) -> Bool {
        guard tubeIndex >= 0 && tubeIndex < tubes.count else { return true }
        return tubes[tubeIndex].isEmpty
    }
}

// MARK: - Ball Sort Move

struct BallSortMove {
    let from: Int
    let to: Int
    let ballCount: Int
    let color: PegColor
}

// MARK: - Ball Sort Game State

enum BallSortGameState: Equatable {
    case playing
    case won(moves: Int, stars: Int)
    case paused
}
