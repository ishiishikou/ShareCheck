import XCTest
@testable import ShareCheck

final class ShareCheckStoreLogicTests: XCTestCase {
    func testMarkSetsSharedAndReviewedStatuses() {
        var statuses: [String: MediaStatus] = [:]

        let operation = MediaStatusStoreLogic.mark(
            statuses: &statuses,
            sharedIds: ["shared-1", "shared-2"],
            reviewedIds: ["reviewed-1"]
        )

        XCTAssertEqual(statuses["shared-1"], .shared)
        XCTAssertEqual(statuses["shared-2"], .shared)
        XCTAssertEqual(statuses["reviewed-1"], .reviewed)
        XCTAssertEqual(operation?.sharedIds, ["shared-1", "shared-2"])
        XCTAssertEqual(operation?.reviewedIds, ["reviewed-1"])
    }

    func testMarkReturnsNilWhenNoIdsChanged() {
        var statuses: [String: MediaStatus] = [:]

        let operation = MediaStatusStoreLogic.mark(
            statuses: &statuses,
            sharedIds: [],
            reviewedIds: []
        )

        XCTAssertNil(operation)
        XCTAssertTrue(statuses.isEmpty)
    }

    func testUndoRemovesLatestOperationStatuses() {
        var statuses: [String: MediaStatus] = [
            "shared-1": .shared,
            "reviewed-1": .reviewed,
            "unrelated": .shared
        ]
        let operation = OperationSnapshot(
            sharedIds: ["shared-1"],
            reviewedIds: ["reviewed-1"],
            createdAt: Date()
        )

        MediaStatusStoreLogic.undo(statuses: &statuses, operation: operation)

        XCTAssertNil(statuses["shared-1"])
        XCTAssertNil(statuses["reviewed-1"])
        XCTAssertEqual(statuses["unrelated"], .shared)
    }

    func testUndoWithNilOperationDoesNothing() {
        var statuses: [String: MediaStatus] = ["shared-1": .shared]

        MediaStatusStoreLogic.undo(statuses: &statuses, operation: nil)

        XCTAssertEqual(statuses["shared-1"], .shared)
    }
}
