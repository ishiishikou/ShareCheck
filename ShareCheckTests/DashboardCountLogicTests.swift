import XCTest
@testable import ShareCheck

final class DashboardCountLogicTests: XCTestCase {
    func testMakeCountsClassifiesDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 27, hour: 12)))
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 27, hour: 9)))
        let yesterday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 26, hour: 9)))
        let sameWeek = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 25, hour: 9)))
        let older = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 9)))
        let counts = DashboardCountLogic.makeCounts(dates: [today, yesterday, sameWeek, older], now: now, calendar: calendar)
        XCTAssertEqual(counts, DashboardCounts(total: 4, today: 1, yesterday: 1, thisWeek: 1, older: 1))
    }
}
