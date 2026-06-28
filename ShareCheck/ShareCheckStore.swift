import Foundation

@MainActor
final class ShareCheckStore: ObservableObject {
    @Published private(set) var statuses: [String: MediaStatus] = [:]
    @Published var latestOperation: OperationSnapshot?
    @Published var skipSharedConfirmation: Bool
    @Published var skipReviewedConfirmation: Bool
    @Published private(set) var managementStartDate: Date

    private let statusesKey = "mediaStatuses"
    private let startDateKey = "managementStartDate"
    private let latestOperationKey = "latestOperation"
    private let skipSharedKey = "skipSharedConfirmation"
    private let skipReviewedKey = "skipReviewedConfirmation"

    init() {
        if let storedStartDate = UserDefaults.standard.object(forKey: startDateKey) as? Date {
            managementStartDate = storedStartDate
        } else {
            let initialStartDate = Date()
            managementStartDate = initialStartDate
            UserDefaults.standard.set(initialStartDate, forKey: startDateKey)
        }

        if let data = UserDefaults.standard.data(forKey: statusesKey), let decoded = try? JSONDecoder().decode([String: MediaStatus].self, from: data) {
            statuses = decoded
        }
        if let data = UserDefaults.standard.data(forKey: latestOperationKey), let decoded = try? JSONDecoder().decode(OperationSnapshot.self, from: data) {
            latestOperation = decoded
        }
        skipSharedConfirmation = UserDefaults.standard.bool(forKey: skipSharedKey)
        skipReviewedConfirmation = UserDefaults.standard.bool(forKey: skipReviewedKey)
    }

    func status(for id: String) -> MediaStatus { statuses[id] ?? .pending }

    func mark(sharedIds: [String], reviewedIds: [String]) {
        guard let operation = MediaStatusStoreLogic.mark(statuses: &statuses, sharedIds: sharedIds, reviewedIds: reviewedIds) else {
            return
        }
        latestOperation = operation
        persist()
    }

    func undoLatestOperation() {
        MediaStatusStoreLogic.undo(statuses: &statuses, operation: latestOperation)
        latestOperation = nil
        persist()
    }

    func resetManagementStartDate() {
        managementStartDate = Date()
        UserDefaults.standard.set(managementStartDate, forKey: startDateKey)
        statuses.removeAll()
        latestOperation = nil
        persist()
    }

    func removeStatuses(missingFrom existingIds: Set<String>) {
        let originalStatuses = statuses
        let originalLatestOperation = latestOperation

        statuses = statuses.filter { existingIds.contains($0.key) }

        if let latestOperation {
            let sharedIds = latestOperation.sharedIds.filter { existingIds.contains($0) }
            let reviewedIds = latestOperation.reviewedIds.filter { existingIds.contains($0) }
            let prunedOperation = OperationSnapshot(sharedIds: sharedIds, reviewedIds: reviewedIds, createdAt: latestOperation.createdAt)
            self.latestOperation = prunedOperation.isEmpty ? nil : prunedOperation
        }

        if statuses != originalStatuses || latestOperation != originalLatestOperation {
            persist()
        }
    }

    func setSkipSharedConfirmation(_ value: Bool) {
        skipSharedConfirmation = value
        UserDefaults.standard.set(value, forKey: skipSharedKey)
    }

    func setSkipReviewedConfirmation(_ value: Bool) {
        skipReviewedConfirmation = value
        UserDefaults.standard.set(value, forKey: skipReviewedKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(statuses) { UserDefaults.standard.set(data, forKey: statusesKey) }
        if let latestOperation, let data = try? JSONEncoder().encode(latestOperation) {
            UserDefaults.standard.set(data, forKey: latestOperationKey)
        } else {
            UserDefaults.standard.removeObject(forKey: latestOperationKey)
        }
    }
}
