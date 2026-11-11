import Foundation
import XCTest

@testable import FreeSudokuCore

final class SessionStoreTests: XCTestCase {
    private var directory: URL!
    private var store: SessionStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = SessionStore(url: directory.appendingPathComponent("nested/session.json"))
    }

    override func tearDownWithError() throws {
        // Only remove this test's uniquely named fixture directory.
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func testMissingSaveDoesNotCreateFiles() throws {
        XCTAssertNil(try store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testDiskRoundTripAndAtomicReplacement() throws {
        var session = try fixture()
        session.game.enter(2, at: 0, asNote: true)
        session.game.enter(1, at: 0)
        session.game.undo()
        session.game.tick()
        try store.save(session)
        XCTAssertEqual(try store.load(), session)
        session.game.redo()
        session.game.tick()
        try store.save(session)
        XCTAssertEqual(try store.load(), session)
        let files = try FileManager.default.contentsOfDirectory(atPath: store.url.deletingLastPathComponent().path)
        XCTAssertEqual(files, ["session.json"])
    }

    func testCorruptSaveRemainsUntouched() throws {
        try store.save(fixture())
        let corrupt = Data("not a saved game".utf8)
        try corrupt.write(to: store.url)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(try Data(contentsOf: store.url), corrupt)
    }

    func testOversizedSaveIsRejectedWithoutModification() throws {
        try store.save(fixture())
        let oversized = Data(repeating: 32, count: SavedSession.maximumBytes + 1)
        try oversized.write(to: store.url)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(try Data(contentsOf: store.url), oversized)
    }

    func testWriteFailureIsSurfaced() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let blocker = directory.appendingPathComponent("nested")
        let original = Data("This file is not a directory".utf8)
        try original.write(to: blocker)
        XCTAssertThrowsError(try store.save(fixture()))
        XCTAssertEqual(try Data(contentsOf: blocker), original)
    }

    func testReadFailureIsNotTreatedAsMissingSave() throws {
        try FileManager.default.createDirectory(at: store.url, withIntermediateDirectories: true)
        XCTAssertThrowsError(try store.load())
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    private func fixture() throws -> SavedSession {
        let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
        var clues = solution
        clues[0] = 0
        clues[1] = 0
        let puzzle = try Puzzle(clues: clues, solution: solution, difficulty: .easy)
        return SavedSession(game: Game(puzzle: puzzle), statistics: Statistics())
    }
}
