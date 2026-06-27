import AVFoundation
import Combine
import Foundation
import Photos
import UniformTypeIdentifiers

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
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND (mediaType == %d OR mediaType == %d)",
            startDate as NSDate,
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )

        let fetchResult = PHAsset.fetchAssets(with: options)
        var loaded: [MediaItem] = []
        fetchResult.enumerateObjects { asset, _, _ in
            if store.status(for: asset.localIdentifier) == .pending {
                loaded.append(MediaItem(asset: asset))
            }
        }
        items = loaded
    }

    func makeShareItems(from assets: [PHAsset]) async -> [Any] {
        var shareItems: [Any] = []
        for asset in assets {
            if asset.mediaType == .image, let url = await imageFileURL(for: asset) {
                shareItems.append(url)
            } else if asset.mediaType == .video, let url = await videoURL(for: asset) {
                shareItems.append(url)
            }
        }
        return shareItems
    }

    private func imageFileURL(for asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.version = .current

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, uti, _, _ in
                guard let data else {
                    continuation.resume(returning: nil)
                    return
                }

                let type = uti.flatMap { UTType($0) }
                let ext = type?.preferredFilenameExtension ?? "jpg"
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent(asset.localIdentifier.safeFileName)
                    .appendingPathExtension(ext)

                do {
                    try data.write(to: url, options: .atomic)
                    continuation.resume(returning: url)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func videoURL(for asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    continuation.resume(returning: urlAsset.url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

private extension String {
    var safeFileName: String {
        replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }
}
