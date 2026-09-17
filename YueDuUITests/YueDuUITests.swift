import XCTest

final class YueDuUITests: XCTestCase {
    func testLaunchShowsTabs() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["书架"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["书城"].exists)
        XCTAssertTrue(app.tabBars.buttons["设置"].exists)
    }
}
