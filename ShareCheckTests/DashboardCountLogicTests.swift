import XCTest
@testable import ShareCheck

final class DashboardCountLogicTests: XCTestCase {
    func testMakeCountsClassifiesTodayYesterdayThisWeekAndOlder() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 27,
            hour: 12
        )))
        let today = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 27,
            hour: 9
        )))
        let yesterday = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 26,
            hour: 9
        )))
        let sameWeek = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 25,
            hour: 9
        )))
        let older = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 5,
            day: 1,
            hour: 9
        )))

        let counts = DashboardCountLogic.makeCounts(
            dates: [today, yesterday, sameWeek, older],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(counts.total, 4)
        XCTAssertEqual(counts.today, 1)
        XCTAssertEqual(counts.yesterday, 1)
        XCTAssertEqual(counts.thisWeek, 1)
        XCTAssertEqual(counts.older, 1)
    }

    func testMakeCountsReturnsEmptyForNoDates() {
        let counts = DashboardCountLogic.makeCounts(dates: [])

        XCTAssertEqual(counts.total, 0)
        XCTAssertEqual(counts.today, 0)
        XCTAssertEqual(counts.yesterday, 0)
        XCTAssertEqual(counts.thisWeek, 0)
        XCTAssertEqual(counts.older, 0)
    }
}
