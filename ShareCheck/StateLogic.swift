import Foundation

struct MediaStatusStoreLogic {
    static func mark(
        statuses: inout [String: MediaStatus],
        sharedIds: [String],
        reviewedIds: [String]
    ) -> OperationSnapshot? {
        for id in sharedIds {
            statuses[id] = .shared
        }
        for id in reviewedIds {
            statuses[id] = .reviewed
        }

        let operation = OperationSnapshot(
            sharedIds: sharedIds,
            reviewedIds: reviewedIds,
            createdAt: Date()
        )

        return operation.isEmpty ? nil : operation
    }

    static func undo(
        statuses: inout [String: MediaStatus],
        operation: OperationSnapshot?
    ) {
        guard let operation else { return }

        for id in operation.sharedIds {
            statuses.removeValue(forKey: id)
        }
        for id in operation.reviewedIds {
            statuses.removeValue(forKey: id)
        }
    }
}

struct DashboardCountLogic {
    static func makeCounts(
        dates: [Date],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DashboardCounts {
        var today = 0
        var yesterday = 0
        var thisWeek = 0
        var older = 0

        let todayStart = calendar.startOfDay(for: now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart

        for date in dates {
            let dayStart = calendar.startOfDay(for: date)
            if dayStart == todayStart {
                today += 1
            } else if dayStart == yesterdayStart {
                yesterday += 1
            } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
                thisWeek += 1
            } else {
                older += 1
            }
        }

        return DashboardCounts(
            total: dates.count,
            today: today,
            yesterday: yesterday,
            thisWeek: thisWeek,
            older: older
        )
    }
}
