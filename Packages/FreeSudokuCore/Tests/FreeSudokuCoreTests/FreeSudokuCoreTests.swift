import XCTest
@testable import FreeSudokuCore

final class FreeSudokuCoreTests: XCTestCase {
    private func fixture() throws -> Puzzle {
        let solution = (0..<81).map { index in
            (index / 9 * 3 + index / 27 + index % 9) % 9 + 1
        }
        var clues = solution
        clues[0] = 0
        clues[1] = 0
        return try Puzzle(clues: clues, solution: solution, difficulty: .easy)
    }

    func testGeneratedPuzzlesHaveOneSolution() throws {
        var random = SeededRandom()
        for difficulty in Difficulty.allCases {
            for _ in 0..<3 {
                let puzzle = Puzzle.generate(difficulty: difficulty, using: &random)
                try puzzle.validate()
                XCTAssertEqual(Sudoku.solutionCount(puzzle.clues), 1)
                XCTAssertTrue(Sudoku.isValid(puzzle.solution))
                XCTAssertFalse(puzzle.solution.contains(0))
                XCTAssertGreaterThanOrEqual(puzzle.clues.filter { $0 != 0 }.count, difficulty.targetClues)
                XCTAssertLessThan(puzzle.clues.filter { $0 != 0 }.count, 81)
            }
        }
    }

    func testInvalidAndAmbiguousBoards() {
        XCTAssertEqual(Sudoku.solutionCount([]), 0)
        XCTAssertEqual(Sudoku.solutionCount(Array(repeating: 10, count: 81)), 0)
        XCTAssertEqual(Sudoku.solutionCount(Array(repeating: 0, count: 81)), 2)
        var board = Array(repeating: 0, count: 81)
        board[0] = 1
        board[10] = 1
        XCTAssertEqual(Sudoku.solutionCount(board), 0)
        XCTAssertEqual(Sudoku.peers(of: 0).count, 20)
        XCTAssertTrue(Sudoku.peers(of: -1).isEmpty)
    }

    func testValidPartialBoardCanStillBeUnsolvable() {
        var board = Array(repeating: 0, count: 81)
        for index in 0..<8 { board[index] = index + 1 }
        board[17] = 9
        XCTAssertTrue(Sudoku.isValid(board))
        XCTAssertEqual(Sudoku.solutionCount(board), 0)
        XCTAssertEqual(Sudoku.solutionCount(board, limit: 0), 0)
    }

    func testHistoryLimitAndNoteToggle() throws {
        var game = Game(puzzle: try fixture())
        game.enter(3, at: 0, asNote: true)
        game.enter(3, at: 0, asNote: true)
        XCTAssertTrue(game.board.notes[0].isEmpty)
        for _ in 0..<205 {
            game.enter(1, at: 0)
            game.erase(at: 0)
        }
        XCTAssertEqual(game.undoHistory.count, 200)
        for _ in 0..<200 { game.undo() }
        XCTAssertFalse(game.canUndo)
        XCTAssertEqual(game.redoHistory.count, 200)
        try game.validate()
        let save = SavedSession(game: game, statistics: Statistics())
        XCTAssertEqual(try SavedSession.decode(save.encoded()), save)
        game.enter(5, at: 0)
        XCTAssertFalse(game.canRedo)
    }

    func testNotesUndoRedoAndBranching() throws {
        var game = Game(puzzle: try fixture())
        game.enter(3, at: 0, asNote: true)
        XCTAssertEqual(game.board.notes[0], [3])
        game.undo()
        XCTAssertTrue(game.board.notes[0].isEmpty)
        game.redo()
        XCTAssertEqual(game.board.notes[0], [3])
        game.enter(1, at: 0)
        XCTAssertTrue(game.board.notes[0].isEmpty)
        game.undo()
        XCTAssertEqual(game.board.notes[0], [3])
        game.erase(at: 0)
        XCTAssertFalse(game.canRedo)
        game.enter(9, at: 2)
        XCTAssertEqual(game.board.values[2], game.puzzle.clues[2])
        game.enter(0, at: -1)
        game.erase(at: 81)
    }

    func testCompletionHintsAndStatistics() throws {
        var game = Game(puzzle: try fixture())
        game.tick()
        XCTAssertEqual(game.hint(at: -1), 0)
        XCTAssertEqual(game.hint(at: 1), 1)
        XCTAssertTrue(game.isComplete)
        XCTAssertEqual(game.hintsUsed, 2)
        XCTAssertNil(game.hint(at: 0))
        game.tick()
        XCTAssertEqual(game.elapsedSeconds, 1)
        var statistics = Statistics()
        statistics.record(game)
        statistics.record(game)
        XCTAssertEqual(statistics.completed, 1)
        XCTAssertEqual(statistics.bestSeconds, 1)
    }

    func testSaveRoundTripIncludesHistoryAndNotes() throws {
        var game = Game(puzzle: try fixture())
        game.enter(4, at: 0, asNote: true)
        game.enter(1, at: 0)
        game.undo()
        game.tick()
        let session = SavedSession(game: game, statistics: Statistics())
        XCTAssertEqual(try SavedSession.decode(session.encoded()), session)
    }

    func testCorruptAndUnsupportedSavesAreRejected() throws {
        XCTAssertThrowsError(try SavedSession.decode(Data("invalid".utf8)))
        let session = SavedSession(game: Game(puzzle: try fixture()), statistics: Statistics())
        let data = try session.encoded()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["version"] = 99
        XCTAssertThrowsError(try SavedSession.decode(JSONSerialization.data(withJSONObject: json)))
        json["version"] = 1
        var game = try XCTUnwrap(json["game"] as? [String: Any])
        var board = try XCTUnwrap(game["board"] as? [String: Any])
        board["values"] = [1, 2]
        game["board"] = board
        json["game"] = game
        XCTAssertThrowsError(try SavedSession.decode(JSONSerialization.data(withJSONObject: json)))
    }
}

private struct SeededRandom: RandomNumberGenerator {
    var state: UInt64 = 42
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
