import SwiftUI
import Photos

struct ThumbnailView: View {
    let asset: PHAsset
    let isSelected: Bool

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(.quaternary)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()

            if asset.mediaType == .video {
                Image(systemName: "video.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(4)
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .blue)
                    .font(.title3)
                    .padding(4)
            }
        }
        .contentShape(Rectangle())
        .task(id: asset.localIdentifier) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let targetSize = CGSize(width: 220, height: 220)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        await withCheckedContinuation { continuation in
            PHCachingImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { result, _ in
                image = result
                continuation.resume()
            }
        }
    }
}
