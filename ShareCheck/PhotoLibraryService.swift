import Foundation
import Photos

@MainActor
final class PhotoLibraryService: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var items: [MediaItem] = []

    func requestAuthorizationIfNeeded() async {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .notDetermined {
            authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        } else {
            authorizationStatus = current
        }
    }

    func loadItems(startDate: Date, store: ShareCheckStore) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "creationDate >= %@ AND (mediaType == %d OR mediaType == %d)", startDate as NSDate, PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        let fetchResult = PHAsset.fetchAssets(with: options)
        var loaded: [MediaItem] = []
        fetchResult.enumerateObjects { asset, _, _ in
            if store.status(for: asset.localIdentifier) == .pending { loaded.append(MediaItem(asset: asset)) }
        }
        items = loaded
    }
}
