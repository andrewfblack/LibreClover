import Foundation

public struct BoardState: Codable, Equatable, Sendable {
    public internal(set) var values: [Int]
    public internal(set) var notes: [Set<Int>]
}

public struct Game: Codable, Equatable, Sendable {
    public let id: UUID
    public let puzzle: Puzzle
    public private(set) var board: BoardState
    public private(set) var undoHistory: [BoardState] = []
    public private(set) var redoHistory: [BoardState] = []
    public private(set) var hintsUsed = 0
    public private(set) var elapsedSeconds = 0
    public var isComplete: Bool { board.values == puzzle.solution }
    public var canUndo: Bool { !undoHistory.isEmpty }
    public var canRedo: Bool { !redoHistory.isEmpty }

    public init(puzzle: Puzzle) {
        id = UUID()
        self.puzzle = puzzle
        board = BoardState(values: puzzle.clues, notes: Array(repeating: [], count: 81))
    }

    public mutating func enter(_ value: Int, at index: Int, asNote: Bool = false) {
        guard !isComplete, (0..<81).contains(index), (1...9).contains(value),
              puzzle.clues[index] == 0 else { return }
        if asNote {
            guard board.values[index] == 0 else { return }
            remember()
            if board.notes[index].contains(value) { board.notes[index].remove(value) }
            else { board.notes[index].insert(value) }
        } else {
            guard board.values[index] != value else { return }
            remember()
            board.values[index] = value
            board.notes[index] = []
        }
    }

    public mutating func erase(at index: Int) {
        guard !isComplete, (0..<81).contains(index), puzzle.clues[index] == 0,
              board.values[index] != 0 || !board.notes[index].isEmpty else { return }
        remember()
        board.values[index] = 0
        board.notes[index] = []
    }

    @discardableResult public mutating func hint(at preferredIndex: Int?) -> Int? {
        guard !isComplete else { return nil }
        let index: Int?
        if let preferredIndex, (0..<81).contains(preferredIndex),
           board.values[preferredIndex] != puzzle.solution[preferredIndex] {
            index = preferredIndex
        } else {
            index = (0..<81).first { board.values[$0] != puzzle.solution[$0] }
        }
        guard let index else { return nil }
        enter(puzzle.solution[index], at: index)
        if hintsUsed < Int.max { hintsUsed += 1 }
        return index
    }

    public mutating func undo() {
        guard !isComplete, let previous = undoHistory.popLast() else { return }
        redoHistory.append(board)
        board = previous
    }

    public mutating func redo() {
        guard !isComplete, let next = redoHistory.popLast() else { return }
        undoHistory.append(board)
        board = next
    }

    public mutating func tick() {
        if !isComplete && elapsedSeconds < Int.max { elapsedSeconds += 1 }
    }

    private mutating func remember() {
        undoHistory.append(board)
        if undoHistory.count > 200 { undoHistory.removeFirst() }
        redoHistory.removeAll()
    }

    public func validate() throws {
        try puzzle.validate()
        guard hintsUsed >= 0, elapsedSeconds >= 0, undoHistory.count <= 200, redoHistory.count <= 200 else {
            throw GameError.invalidSave
        }
        for state in [board] + undoHistory + redoHistory {
            guard state.values.count == 81, state.notes.count == 81,
                  state.values.allSatisfy({ (0...9).contains($0) }),
                  state.notes.allSatisfy({ $0.allSatisfy { (1...9).contains($0) } }),
                  (0..<81).allSatisfy({ puzzle.clues[$0] == 0 || state.values[$0] == puzzle.clues[$0] }) else {
                throw GameError.invalidSave
            }
        }
    }
}

public struct Statistics: Codable, Equatable, Sendable {
    public private(set) var completed = 0
    public private(set) var bestSeconds: Int?
    public private(set) var lastCompletedGame: UUID?

    public init() {}

    public mutating func record(_ game: Game) {
        guard game.isComplete, lastCompletedGame != game.id else { return }
        if completed < Int.max { completed += 1 }
        bestSeconds = min(bestSeconds ?? game.elapsedSeconds, game.elapsedSeconds)
        lastCompletedGame = game.id
    }
}

public struct SavedSession: Codable, Equatable, Sendable {
    public static let maximumBytes = 5_000_000
    public let version: Int
    public var game: Game
    public var statistics: Statistics

    public init(game: Game, statistics: Statistics) {
        version = 1
        self.game = game
        self.statistics = statistics
    }

    public func encoded() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public static func decode(_ data: Data) throws -> SavedSession {
        guard data.count <= maximumBytes else { throw GameError.invalidSave }
        let session = try JSONDecoder().decode(Self.self, from: data)
        guard session.version == 1, session.statistics.completed >= 0,
              session.statistics.bestSeconds.map({ $0 >= 0 }) ?? true else { throw GameError.invalidSave }
        try session.game.validate()
        return session
    }
}
