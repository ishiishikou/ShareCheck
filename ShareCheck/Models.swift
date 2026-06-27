import Foundation
import Photos

enum MediaStatus: String, Codable {
    case pending
    case shared
    case reviewed
}

struct MediaItem: Identifiable, Hashable {
    let asset: PHAsset

    var id: String { asset.localIdentifier }

    var creationDate: Date {
        asset.creationDate ?? .distantPast
    }

    var isVideo: Bool {
        asset.mediaType == .video
    }
}

struct OperationSnapshot: Codable {
    var sharedIds: [String]
    var reviewedIds: [String]
    var createdAt: Date

    var isEmpty: Bool {
        sharedIds.isEmpty && reviewedIds.isEmpty
    }
}

struct DashboardCounts: Equatable {
    var total: Int
    var today: Int
    var yesterday: Int
    var thisWeek: Int
    var older: Int

    static let empty = DashboardCounts(total: 0, today: 0, yesterday: 0, thisWeek: 0, older: 0)
}
