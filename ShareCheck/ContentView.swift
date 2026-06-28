import SwiftUI
import Photos
import UIKit

struct ContentView: View {
    @EnvironmentObject private var store: ShareCheckStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var photoService = PhotoLibraryService()

    private var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("--ui-testing") }

    var body: some View {
        TabView {
            DashboardView(photoService: photoService)
                .tabItem { Label("ホーム", systemImage: "house") }
            PendingGridView(photoService: photoService)
                .tabItem { Label("未処理", systemImage: "square.grid.3x3") }
            SettingsView(photoService: photoService)
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .task {
            await refreshPhotoLibrary()
        }
        .onChange(of: store.statuses) { _, _ in
            guard !isUITesting else { return }
            photoService.loadItems(startDate: store.managementStartDate, store: store)
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task { await refreshPhotoLibrary() }
        }
    }

    private func refreshPhotoLibrary() async {
        guard !isUITesting else { return }
        await photoService.requestAuthorizationIfNeeded()
        photoService.loadItems(startDate: store.managementStartDate, store: store)
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: ShareCheckStore
    @ObservedObject var photoService: PhotoLibraryService

    private var counts: DashboardCounts { DashboardCountLogic.makeCounts(dates: photoService.items.map(\.creationDate)) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(counts.total == 0 ? "✓ 共有漏れはありません" : "未処理")
                            .font(.headline)
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(counts.total)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(counts.total == 0 ? .green : .blue)
                            Text("件")
                                .font(.title3)
                            if counts.total == 0 {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("内訳") {
                    row("今日", counts.today)
                    row("昨日", counts.yesterday)
                    row("今週", counts.thisWeek)
                    row("それ以前", counts.older)
                }

                if let latest = store.latestOperation {
                    Section("直近の操作") {
                        if !latest.sharedIds.isEmpty { row("共有済み", latest.sharedIds.count) }
                        if !latest.reviewedIds.isEmpty { row("確認済み", latest.reviewedIds.count) }
                        Button(role: .destructive) {
                            store.undoLatestOperation()
                        } label: {
                            Label("元に戻す", systemImage: "arrow.uturn.backward")
                        }
                    }
                }
            }
            .navigationTitle("ShareCheck")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        photoService.loadItems(startDate: store.managementStartDate, store: store)
                    } label: {
                        Label("更新", systemImage: "arrow.clockwise")
                    }
                    .disabled(photoService.isLoading)
                }
            }
        }
    }

    private func row(_ title: String, _ count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)件")
                .foregroundStyle(.secondary)
        }
    }
}

struct PendingGridView: View {
    @EnvironmentObject private var store: ShareCheckStore
    @ObservedObject var photoService: PhotoLibraryService

    @State private var selectedIds: Set<String> = []
    @State private var shareItems: [Any] = []
    @State private var isPreparingShare = false
    @State private var showShareSheet = false
    @State private var showPostShareConfirmation = false
    @State private var pendingSelectedIds: [String] = []
    @State private var dragSelectionTarget: Bool?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(photoService.items) { item in
                            ThumbnailView(asset: item.asset, isSelected: selectedIds.contains(item.id))
                                .frame(height: max((geometry.size.width - 4) / 3, 1))
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                updateSelection(at: value.location, gridWidth: geometry.size.width)
                            }
                            .onEnded { _ in
                                dragSelectionTarget = nil
                            }
                    )
                }
            }
            .navigationTitle("未処理")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(selectedIds.isEmpty ? "すべて選択" : "選択解除") {
                        if selectedIds.isEmpty {
                            selectedIds = Set(photoService.items.map(\.id))
                        } else {
                            selectedIds.removeAll()
                        }
                    }
                    .disabled(photoService.items.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await shareSelected() }
                    } label: {
                        if isPreparingShare {
                            ProgressView()
                        } else {
                            Label("共有", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(selectedIds.isEmpty || isPreparingShare)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !selectedIds.isEmpty {
                    Text("\(selectedIds.count)件選択中")
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.blue)
                        .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: shareItems) { completed in
                    handleShareSheetCompletion(completed: completed)
                }
            }
            .sheet(isPresented: $showPostShareConfirmation) {
                PostShareConfirmationView(
                    selectedIds: pendingSelectedIds,
                    remainingIds: remainingIds(excluding: pendingSelectedIds),
                    confirmShared: !store.skipSharedConfirmation,
                    confirmReviewed: !store.skipReviewedConfirmation
                ) { sharedIds, reviewedIds in
                    store.mark(sharedIds: sharedIds, reviewedIds: reviewedIds)
                    clearSelectionState()
                    showPostShareConfirmation = false
                }
            }
            .overlay {
                if photoService.authorizationStatus == .denied || photoService.authorizationStatus == .restricted {
                    ContentUnavailableView(
                        "写真へのアクセスが必要です",
                        systemImage: "photo",
                        description: Text("設定アプリから写真ライブラリへのアクセスを許可してください。")
                    )
                } else if photoService.isLoading {
                    ProgressView("読み込み中")
                } else if photoService.items.isEmpty {
                    ContentUnavailableView(
                        "未処理はありません",
                        systemImage: "checkmark.circle",
                        description: Text("共有漏れはありません。")
                    )
                }
            }
        }
    }

    private func updateSelection(at location: CGPoint, gridWidth: CGFloat) {
        let spacing: CGFloat = 2
        let columnCount = 3
        let cellWidth = (gridWidth - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
        let stride = cellWidth + spacing
        guard cellWidth > 0, location.x >= 0, location.y >= 0 else { return }

        let column = Int(location.x / stride)
        let row = Int(location.y / stride)
        guard column >= 0, column < columnCount, row >= 0 else { return }

        let xInCell = location.x - CGFloat(column) * stride
        let yInCell = location.y - CGFloat(row) * stride
        guard xInCell <= cellWidth, yInCell <= cellWidth else { return }

        let index = row * columnCount + column
        guard photoService.items.indices.contains(index) else { return }

        let id = photoService.items[index].id
        if dragSelectionTarget == nil {
            dragSelectionTarget = !selectedIds.contains(id)
        }
        setSelection(id, selected: dragSelectionTarget ?? true)
    }

    private func setSelection(_ id: String, selected: Bool) {
        if selected {
            selectedIds.insert(id)
        } else {
            selectedIds.remove(id)
        }
    }

    private func shareSelected() async {
        isPreparingShare = true
        defer { isPreparingShare = false }

        let selectedAssets = photoService.items
            .filter { selectedIds.contains($0.id) }
            .map(\.asset)
        pendingSelectedIds = selectedAssets.map(\.localIdentifier)
        shareItems = await photoService.makeShareItems(from: selectedAssets)

        if shareItems.isEmpty {
            pendingSelectedIds.removeAll()
            return
        }
        showShareSheet = true
    }

    private func handleShareSheetCompletion(completed: Bool) {
        showShareSheet = false
        guard completed else {
            shareItems.removeAll()
            pendingSelectedIds.removeAll()
            return
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            completeShareFlowAfterShareSheet()
        }
    }

    private func completeShareFlowAfterShareSheet() {
        if store.skipSharedConfirmation && store.skipReviewedConfirmation {
            store.mark(sharedIds: pendingSelectedIds, reviewedIds: remainingIds(excluding: pendingSelectedIds))
            clearSelectionState()
        } else {
            showPostShareConfirmation = true
        }
    }

    private func remainingIds(excluding ids: [String]) -> [String] {
        let excluded = Set(ids)
        return photoService.items.map(\.id).filter { !excluded.contains($0) }
    }

    private func clearSelectionState() {
        selectedIds.removeAll()
        pendingSelectedIds.removeAll()
        shareItems.removeAll()
    }
}

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
                        .overlay {
                            Image(systemName: asset.mediaType == .video ? "video" : "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            if asset.mediaType == .video {
                Image(systemName: "video.fill")
                    .font(.caption)
                    .padding(5)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .background(Circle().fill(.white))
                    .padding(5)
            }
        }
        .contentShape(Rectangle())
        .task(id: asset.localIdentifier) {
            image = await loadThumbnail(for: asset)
        }
    }

    private func loadThumbnail(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 300, height: 300),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

struct PostShareConfirmationView: View {
    @EnvironmentObject private var store: ShareCheckStore
    let selectedIds: [String]
    let remainingIds: [String]
    let confirmShared: Bool
    let confirmReviewed: Bool
    let onComplete: ([String], [String]) -> Void

    @State private var sharedDecision = true
    @State private var reviewedDecision = false
    @State private var skipShared = false
    @State private var skipReviewed = false

    var body: some View {
        NavigationStack {
            Form {
                if confirmShared {
                    Section("選択した写真") {
                        Toggle("\(selectedIds.count)件を共有済みにする", isOn: $sharedDecision)
                        Toggle("次回から確認しない", isOn: $skipShared)
                    }
                }

                if confirmReviewed {
                    Section("残りの写真") {
                        Toggle("\(remainingIds.count)件を確認済みにする", isOn: $reviewedDecision)
                        Text("確認済みにすると未処理一覧へ表示されなくなります。直近の操作から取り消せます。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Toggle("次回から確認しない", isOn: $skipReviewed)
                    }
                }
            }
            .navigationTitle("共有を終えましたか？")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        if confirmShared { store.setSkipSharedConfirmation(skipShared) }
                        if confirmReviewed { store.setSkipReviewedConfirmation(skipReviewed) }

                        onComplete(
                            confirmShared ? (sharedDecision ? selectedIds : []) : selectedIds,
                            confirmReviewed ? (reviewedDecision ? remainingIds : []) : remainingIds
                        )
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("あとで") { onComplete([], []) }
                }
            }
            .onAppear {
                skipShared = store.skipSharedConfirmation
                skipReviewed = store.skipReviewedConfirmation
                sharedDecision = true
                reviewedDecision = store.skipReviewedConfirmation
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: ShareCheckStore
    @ObservedObject var photoService: PhotoLibraryService

    var body: some View {
        NavigationStack {
            Form {
                Section("管理設定") {
                    HStack {
                        Text("管理開始日時")
                        Spacer()
                        Text(store.managementStartDate, style: .date)
                            .foregroundStyle(.secondary)
                    }
                    Button(role: .destructive) {
                        store.resetManagementStartDate()
                        photoService.loadItems(startDate: store.managementStartDate, store: store)
                    } label: {
                        Text("管理開始日時をリセット")
                    }
                }
                Section("確認") {
                    Toggle("共有済み確認を省略", isOn: Binding(get: { store.skipSharedConfirmation }, set: { store.setSkipSharedConfirmation($0) }))
                    Toggle("確認済み確認を省略", isOn: Binding(get: { store.skipReviewedConfirmation }, set: { store.setSkipReviewedConfirmation($0) }))
                }
                Section("アプリ情報") {
                    Text("ShareCheck")
                    Text("Version 1.0.0").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
        }
    }
}
