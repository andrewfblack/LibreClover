import XCTest

final class FreeSudokuUITests: XCTestCase {
    func testStartPlayPauseAndResume() throws {
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Let’s play"].waitForExistence(timeout: 5) { app.buttons["Let’s play"].tap() }
        let newPuzzle = app.buttons["newPuzzle"]
        XCTAssertTrue(newPuzzle.waitForExistence(timeout: 10))
        newPuzzle.tap()
        app.buttons["Easy"].tap()
        let replace = app.buttons["Replace with new puzzle"]
        if replace.waitForExistence(timeout: 2) { replace.tap() }
        let firstCell = app.buttons["cell-0"]
        XCTAssertTrue(firstCell.waitForExistence(timeout: 30))
        // Find an editable cell without depending on the randomized puzzle.
        let emptyCell = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cell-' AND value BEGINSWITH 'Empty'")).firstMatch
        XCTAssertTrue(emptyCell.exists)
        emptyCell.tap()
        app.buttons["Enter 1"].tap()
        XCTAssertTrue(app.buttons["Undo"].isEnabled)
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.buttons["Redo"].isEnabled)
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Resume puzzle"].waitForExistence(timeout: 5))
        app.buttons["Resume puzzle"].tap()
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Resume puzzle"].waitForExistence(timeout: 10))
        app.buttons["Resume puzzle"].tap()
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Redo"].isEnabled)
    }
}
