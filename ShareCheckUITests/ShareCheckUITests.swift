import XCTest

final class ShareCheckUITests: XCTestCase {
    func testAppLaunches() {
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing"]
        application.launch()
        XCTAssertTrue(application.tabBars.firstMatch.waitForExistence(timeout: 5))
    }
}
