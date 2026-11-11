import Foundation

public enum Difficulty: String, CaseIterable, Codable, Sendable {
    case easy, medium, hard, expert

    public var title: String { rawValue.capitalized }
    public var targetClues: Int {
        switch self {
        case .easy: return 42
        case .medium: return 36
        case .hard: return 31
        case .expert: return 27
        }
    }
}

public enum Sudoku {
    public static func peers(of index: Int) -> [Int] {
        guard (0..<81).contains(index) else { return [] }
        let row = index / 9, column = index % 9
        return (0..<81).filter {
            $0 != index && ($0 / 9 == row || $0 % 9 == column ||
                ($0 / 27 == row / 3 && $0 % 9 / 3 == column / 3))
        }
    }

    public static func isValid(_ board: [Int]) -> Bool {
        guard board.count == 81, board.allSatisfy({ (0...9).contains($0) }) else { return false }
        return board.indices.allSatisfy { index in
            board[index] == 0 || !peers(of: index).contains { board[$0] == board[index] }
        }
    }

    /// Stops at the requested limit; use two to verify unique solvability.
    public static func solutionCount(_ board: [Int], limit: Int = 2) -> Int {
        guard limit > 0, isValid(board) else { return 0 }
        var working = board
        return search(&working, limit: limit)
    }

    private static func search(_ board: inout [Int], limit: Int) -> Int {
        var bestIndex: Int?
        var bestCandidates = [Int]()
        for index in board.indices where board[index] == 0 {
            let used = Set(peers(of: index).map { board[$0] })
            let candidates = (1...9).filter { !used.contains($0) }
            if candidates.isEmpty { return 0 }
            if bestIndex == nil || candidates.count < bestCandidates.count {
                bestIndex = index
                bestCandidates = candidates
                if candidates.count == 1 { break }
            }
        }
        guard let index = bestIndex else { return 1 }
        var count = 0
        for value in bestCandidates {
            board[index] = value
            count += search(&board, limit: limit - count)
            if count >= limit { break }
        }
        board[index] = 0
        return count
    }
}

public struct Puzzle: Codable, Equatable, Sendable {
    public let clues: [Int]
    public let solution: [Int]
    public let difficulty: Difficulty

    public init(clues: [Int], solution: [Int], difficulty: Difficulty) throws {
        guard Sudoku.isValid(solution), !solution.contains(0), clues.count == 81,
              clues.indices.allSatisfy({ clues[$0] == 0 || clues[$0] == solution[$0] }),
              Sudoku.solutionCount(clues) == 1 else { throw GameError.invalidSave }
        self.clues = clues
        self.solution = solution
        self.difficulty = difficulty
    }

    public static func generate(difficulty: Difficulty) -> Puzzle {
        var random = SystemRandomNumberGenerator()
        return generate(difficulty: difficulty, using: &random)
    }

    public static func generate<R: RandomNumberGenerator>(difficulty: Difficulty, using random: inout R) -> Puzzle {
        // Permutations of rows/bands, columns/stacks and digits preserve a valid completed grid.
        let rows = (0..<3).shuffled(using: &random).flatMap { band in
            (0..<3).shuffled(using: &random).map { band * 3 + $0 }
        }
        let columns = (0..<3).shuffled(using: &random).flatMap { stack in
            (0..<3).shuffled(using: &random).map { stack * 3 + $0 }
        }
        let digits = Array(1...9).shuffled(using: &random)
        let solution = rows.flatMap { row in columns.map { column in
            digits[(row * 3 + row / 3 + column) % 9]
        } }
        var clues = solution
        var remaining = 81
        for index in (0..<81).shuffled(using: &random) {
            if remaining <= difficulty.targetClues { break }
            let value = clues[index]
            clues[index] = 0
            if Sudoku.solutionCount(clues) == 1 { remaining -= 1 }
            else { clues[index] = value }
        }
        // The construction above guarantees validity and uniqueness.
        return Puzzle(uncheckedClues: clues, solution: solution, difficulty: difficulty)
    }

    private init(uncheckedClues: [Int], solution: [Int], difficulty: Difficulty) {
        self.clues = uncheckedClues
        self.solution = solution
        self.difficulty = difficulty
    }

    public func validate() throws {
        _ = try Puzzle(clues: clues, solution: solution, difficulty: difficulty)
    }
}

public enum GameError: Error { case invalidSave }
