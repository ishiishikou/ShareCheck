import Foundation
import Photos

@MainActor
final class PhotoLibraryService: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var items: [MediaItem] = []
    @Published var isLoading = false

    private var observedStartDate: Date?
    private weak var observedStore: ShareCheckStore?

    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func requestAuthorizationIfNeeded() async {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .notDetermined {
            authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        } else {
            authorizationStatus = current
        }
    }

    func loadItems(startDate: Date, store: ShareCheckStore) {
        observedStartDate = startDate
        observedStore = store

        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = current
        guard current == .authorized || current == .limited else {
            items = []
            return
        }

        isLoading = true
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND (mediaType == %d OR mediaType == %d)",
            startDate as NSDate,
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )

        let fetchResult = PHAsset.fetchAssets(with: options)
        var loaded: [MediaItem] = []
        var existingIds = Set<String>()

        fetchResult.enumerateObjects { asset, _, _ in
            existingIds.insert(asset.localIdentifier)
            if store.status(for: asset.localIdentifier) == .pending {
                loaded.append(MediaItem(asset: asset))
            }
        }

        store.removeStatuses(missingFrom: existingIds)
        items = loaded
        isLoading = false
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            self?.reloadObservedItems()
        }
    }

    func makeShareItems(from assets: [PHAsset]) async -> [Any] {
        var urls: [URL] = []
        for asset in assets {
            if let url = await exportAssetResource(asset) {
                urls.append(url)
            }
        }
        return urls
    }

    private func reloadObservedItems() {
        guard let observedStartDate, let observedStore else { return }
        loadItems(startDate: observedStartDate, store: observedStore)
    }

    private func exportAssetResource(_ asset: PHAsset) async -> URL? {
        guard let resource = preferredResource(for: asset) else { return nil }
        let safeFilename = makeSafeFilename(resource.originalFilename, fallbackExtension: asset.mediaType == .video ? "mov" : "jpg")
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareCheck-\(UUID().uuidString)-\(safeFilename)")

        try? FileManager.default.removeItem(at: outputURL)

        return await withCheckedContinuation { continuation in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            PHAssetResourceManager.default().writeData(for: resource, toFile: outputURL, options: options) { error in
                continuation.resume(returning: error == nil ? outputURL : nil)
            }
        }
    }

    private func preferredResource(for asset: PHAsset) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)
        if asset.mediaType == .video {
            return resources.first { $0.type == .video || $0.type == .fullSizeVideo } ?? resources.first
        }
        return resources.first { $0.type == .photo || $0.type == .fullSizePhoto } ?? resources.first
    }

    private func makeSafeFilename(_ filename: String, fallbackExtension: String) -> String {
        let fallback = "media.\(fallbackExtension)"
        let source = filename.isEmpty ? fallback : filename
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return source
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
    }
}
