import Foundation

@MainActor
final class ShareCheckStore: ObservableObject {
    @Published private(set) var statuses: [String: MediaStatus] = [:]
    @Published var latestOperation: OperationSnapshot?
    @Published var skipSharedConfirmation: Bool
    @Published var skipReviewedConfirmation: Bool

    private let statusesKey = "mediaStatuses"
    private let startDateKey = "managementStartDate"
    private let latestOperationKey = "latestOperation"
    private let skipSharedKey = "skipSharedConfirmation"
    private let skipReviewedKey = "skipReviewedConfirmation"

    init() {
        if UserDefaults.standard.object(forKey: startDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: startDateKey)
        }

        if let data = UserDefaults.standard.data(forKey: statusesKey),
           let decoded = try? JSONDecoder().decode([String: MediaStatus].self, from: data) {
            statuses = decoded
        }

        if let data = UserDefaults.standard.data(forKey: latestOperationKey),
           let decoded = try? JSONDecoder().decode(OperationSnapshot.self, from: data) {
            latestOperation = decoded
        }

        skipSharedConfirmation = UserDefaults.standard.bool(forKey: skipSharedKey)
        skipReviewedConfirmation = UserDefaults.standard.bool(forKey: skipReviewedKey)
    }

    var managementStartDate: Date {
        UserDefaults.standard.object(forKey: startDateKey) as? Date ?? Date()
    }

    func status(for id: String) -> MediaStatus {
        statuses[id] ?? .pending
    }

    func mark(sharedIds: [String], reviewedIds: [String]) {
        for id in sharedIds { statuses[id] = .shared }
        for id in reviewedIds { statuses[id] = .reviewed }

        let operation = OperationSnapshot(sharedIds: sharedIds, reviewedIds: reviewedIds, createdAt: Date())
        latestOperation = operation.isEmpty ? nil : operation
        persist()
    }

    func undoLatestOperation() {
        guard let latestOperation else { return }

        for id in latestOperation.sharedIds { statuses.removeValue(forKey: id) }
        for id in latestOperation.reviewedIds { statuses.removeValue(forKey: id) }

        self.latestOperation = nil
        persist()
    }

    func resetManagementStartDate() {
        UserDefaults.standard.set(Date(), forKey: startDateKey)
        statuses.removeAll()
        latestOperation = nil
        persist()
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
        if let data = try? JSONEncoder().encode(statuses) {
            UserDefaults.standard.set(data, forKey: statusesKey)
        }

        if let latestOperation,
           let data = try? JSONEncoder().encode(latestOperation) {
            UserDefaults.standard.set(data, forKey: latestOperationKey)
        } else {
            UserDefaults.standard.removeObject(forKey: latestOperationKey)
        }
    }
}
