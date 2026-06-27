import XCTest

final class ShareCheckUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }
}
