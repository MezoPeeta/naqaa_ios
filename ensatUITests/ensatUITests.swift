//
//  ensatUITests.swift
//  ensatUITests
//
//  Created by Mazen on 16/05/2026.
//

import XCTest

final class EnsatUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each
        // test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface
        // orientation - required for your tests before they run. The setUp method
        // is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of
        // each test method in the class.
    }

    @MainActor
    func testSelectedReciter() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()
        app.activate()
        app/*@START_MENU_TOKEN@*/.buttons["chevron.left"]/*[[".otherElements",".buttons[\"الخلف\"]",".buttons[\"chevron.left\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.firstMatch.tap()
        app/*@START_MENU_TOKEN@*/.buttons["ماهر المعيقلي‏، المصحف المجود"]/*[[".otherElements.buttons[\"ماهر المعيقلي‏، المصحف المجود\"]",".buttons[\"ماهر المعيقلي‏، المصحف المجود\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.firstMatch.tap()

        XCTAssert(app.staticTexts["ماهر المعيقلي"].firstMatch.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
