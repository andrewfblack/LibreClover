import UIKit
import XCTest

final class FreeSudokuUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        if let testRun, testRun.failureCount > 0 {
            let app = XCUIApplication()
            capture("Failure screenshot", app: app)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Failure accessibility hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func testStartPlayPauseAndResume() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-appearance", "light", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
        ]
        app.launch()
        startPuzzle(app)
        capture("Portrait puzzle", app: app)
        // Keep a stable identifier: the empty-cell query changes as digits are entered.
        let emptyCell = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'cell-' AND value BEGINSWITH 'Empty'")
        ).firstMatch
        XCTAssertTrue(emptyCell.exists)
        let editable = app.buttons[emptyCell.identifier]
        reveal(editable, in: app)
        editable.tap()
        let notes = app.descendants(matching: .any)["notesMode"]
        reveal(notes, in: app)
        notes.tap()
        reveal(app.buttons["Enter 1"], in: app)
        app.buttons["Enter 1"].tap()
        XCTAssertTrue((editable.value as? String)?.contains("notes 1") == true)
        reveal(notes, in: app)
        notes.tap()
        reveal(app.buttons["Enter 1"], in: app)
        app.buttons["Enter 1"].tap()
        reveal(app.buttons["Undo"], in: app)
        XCTAssertTrue(app.buttons["Undo"].isEnabled)
        app.buttons["Undo"].tap()
        XCTAssertTrue((editable.value as? String)?.contains("notes 1") == true)
        reveal(app.buttons["Redo"], in: app)
        XCTAssertTrue(app.buttons["Redo"].isEnabled)
        scrollToTop(app)
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Resume puzzle"].waitForExistence(timeout: 5))
        capture("Paused puzzle", app: app)
        app.buttons["Resume puzzle"].tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Resume puzzle"].waitForExistence(timeout: 10))
        app.buttons["Resume puzzle"].tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 5))
        XCTAssertTrue((editable.value as? String)?.contains("notes 1") == true)
        reveal(app.buttons["Redo"], in: app)
        XCTAssertTrue(app.buttons["Redo"].isEnabled)
        scrollToTop(app)

        app.buttons["Settings and statistics"].tap()
        let mistakes = app.switches["Highlight incorrect digits"]
        XCTAssertTrue(mistakes.waitForExistence(timeout: 5))
        mistakes.tap()
        capture("Settings", app: app)
        app.buttons["Done"].tap()
    }

    func testLandscapeScreenshots() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-appearance", "light", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
        ]
        app.launch()
        startPuzzle(app)

        for (orientation, name) in [
            (UIDeviceOrientation.landscapeLeft, "Landscape left puzzle"),
            (UIDeviceOrientation.landscapeRight, "Landscape right puzzle"),
        ] {
            XCUIDevice.shared.orientation = orientation
            let landscape = NSPredicate { _, _ in
                let frame = app.windows.firstMatch.frame
                return frame.width > frame.height
            }
            let rotated = XCTNSPredicateExpectation(predicate: landscape, object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 10), .completed)
            waitForStableBoard(app)
            capture(name, app: app)
        }

        XCUIDevice.shared.orientation = .portrait
        let portrait = NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            return frame.height > frame.width
        }
        let rotated = XCTNSPredicateExpectation(predicate: portrait, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 10), .completed)
        waitForStableBoard(app)
        capture("Portrait after rotation", app: app)
    }

    func testLargeTextAndDarkAppearance() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-appearance", "dark",
        ]
        app.launch()
        startPuzzle(app)
        capture("Large text dark puzzle", app: app)
        let cell = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'cell-' AND value BEGINSWITH 'Empty'")
        ).firstMatch
        reveal(cell, in: app)
        cell.tap()
        reveal(app.buttons["Enter 2"], in: app)
        XCTAssertTrue(app.buttons["Enter 2"].isEnabled)
        XCTAssertGreaterThanOrEqual(app.buttons["Enter 2"].frame.height, 44)
        app.buttons["Enter 2"].tap()
        capture("Large text dark controls", app: app)
    }

    private func startPuzzle(_ app: XCUIApplication) {
        if app.buttons["Let’s play"].waitForExistence(timeout: 5) { app.buttons["Let’s play"].tap() }
        let newPuzzle = app.buttons["newPuzzle"]
        XCTAssertTrue(newPuzzle.waitForExistence(timeout: 10))
        reveal(newPuzzle, in: app)
        newPuzzle.tap()
        app.buttons["Easy"].tap()
        let replace = app.buttons["Replace with new puzzle"]
        if replace.waitForExistence(timeout: 2) { replace.tap() }
        let firstCell = app.buttons["cell-0"]
        XCTAssertTrue(firstCell.waitForExistence(timeout: 30))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cell-'")).count, 81)
        scrollToTop(app)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        if element.isHittable { return }
        scrollToTop(app)
        for _ in 0..<8 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Expected control to be reachable by scrolling")
    }

    private func scrollToTop(_ app: XCUIApplication) {
        for _ in 0..<4 { app.swipeDown() }
    }

    private func waitForStableBoard(_ app: XCUIApplication) {
        var previous: CGRect?
        let stable = NSPredicate { _, _ in
            let frame = app.buttons["cell-0"].frame
            defer { previous = frame }
            return frame.width > 0 && frame == previous
        }
        let expectation = XCTNSPredicateExpectation(predicate: stable, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
    }

    private func capture(_ name: String, app: XCUIApplication) {
        // XCUIApplication.screenshot() can crop using stale portrait bounds after
        // rotation. Capture the native screen, not the app-window rectangle.
        let screenshot = XCUIScreen.main.screenshot()
        let window = app.windows.firstMatch.frame
        XCTAssertEqual(
            screenshot.image.size.width / screenshot.image.size.height,
            window.width / window.height, accuracy: 0.02,
            "Screenshot aspect ratio must match the current window orientation")
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
