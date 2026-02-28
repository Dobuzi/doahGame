//
//  doahGameUITests.swift
//  doahGameUITests
//
//  Created by 김종원 on 10/18/25.
//

import XCTest

final class doahGameUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testStartToGameOverFlow() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-mode"]
        app.launch()

        let startButton = app.buttons["startButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 3))
        startButton.tap()

        // Button should disappear while running.
        XCTAssertFalse(startButton.waitForExistence(timeout: 1))

        // In UI test mode, deterministic obstacle should eventually end the game.
        let gameStateTitle = app.staticTexts["gameStateTitle"]
        XCTAssertTrue(gameStateTitle.waitForExistence(timeout: 3))

        let gameOverPredicate = NSPredicate(format: "label CONTAINS %@", "게임 오버")
        expectation(for: gameOverPredicate, evaluatedWith: gameStateTitle)
        waitForExpectations(timeout: 5)

        // Game over screen should show the restart/start button again.
        XCTAssertTrue(startButton.waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
