import Photos
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ShareCheckStore
    @StateObject private var photoService = PhotoLibraryService()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(photoService: photoService)
                .tabItem { Label("ホーム", systemImage: "house") }
                .tag(0)

            PendingGridView(photoService: photoService)
                .tabItem { Label("未処理", systemImage: "square.grid.3x3") }
                .tag(1)

            SettingsView(photoService: photoService)
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(2)
        }
        .task {
            await photoService.requestAuthorizationIfNeeded()
            photoService.loadItems(startDate: store.managementStartDate, store: store)
        }
        .onChange(of: store.statuses) { _, _ in
            photoService.loadItems(startDate: store.managementStartDate, store: store)
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: ShareCheckStore
    @ObservedObject var photoService: PhotoLibraryService

    private var counts: DashboardCounts {
        DashboardCountLogic.makeCounts(from: photoService.items.map(\.creationDate))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("未処理")
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
                    countRow("今日", counts.today)
                    countRow("昨日", counts.yesterday)
                    countRow("今週", counts.thisWeek)
                    countRow("それ以前", counts.older)
                }

                if let latest = store.latestOperation {
                    Section("直近の操作") {
                        if !latest.sharedIds.isEmpty {
                            countRow("共有済み", latest.sharedIds.count, color: .green)
                        }
                        if !latest.reviewedIds.isEmpty {
                            countRow("確認済み", latest.reviewedIds.count, color: .orange)
                        }
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
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private func countRow(_ title: String, _ count: Int, color: Color = .primary) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)件")
                .foregroundStyle(color)
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

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(photoService.items) { item in
                        ThumbnailView(asset: item.asset, isSelected: selectedIds.contains(item.id))
                            .onTapGesture {
                                toggle(item.id)
                            }
                    }
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
                    Text("\(selectedIds.count)枚選択中")
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.blue)
                        .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: shareItems) {
                    showPostShareConfirmation = true
                }
            }
            .sheet(isPresented: $showPostShareConfirmation) {
                PostShareConfirmationView(
                    selectedIds: pendingSelectedIds,
                    remainingIds: remainingIds(excluding: pendingSelectedIds),
                    onComplete: { sharedIds, reviewedIds in
                        store.mark(sharedIds: sharedIds, reviewedIds: reviewedIds)
                        selectedIds.removeAll()
                        pendingSelectedIds.removeAll()
                        showPostShareConfirmation = false
                    }
                )
            }
            .overlay {
                if photoService.authorizationStatus == .denied || photoService.authorizationStatus == .restricted {
                    ContentUnavailableView("写真へのアクセスが必要です", systemImage: "photo", description: Text("設定アプリから写真ライブラリへのアクセスを許可してください。"))
                } else if photoService.items.isEmpty {
                    ContentUnavailableView("未処理はありません", systemImage: "checkmark.circle", description: Text("共有漏れはありません。"))
                }
            }
        }
    }

    private func toggle(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func shareSelected() async {
        isPreparingShare = true
        let selectedAssets = photoService.items
            .filter { selectedIds.contains($0.id) }
            .map(\.asset)
        pendingSelectedIds = selectedAssets.map(\.localIdentifier)
        shareItems = await photoService.makeShareItems(from: selectedAssets)
        isPreparingShare = false
        if !shareItems.isEmpty {
            showShareSheet = true
        }
    }

    private func remainingIds(excluding ids: [String]) -> [String] {
        let selectedSet = Set(ids)
        return photoService.items.map(\.id).filter { !selectedSet.contains($0) }
    }
}

struct PostShareConfirmationView: View {
    @EnvironmentObject private var store: ShareCheckStore
    let selectedIds: [String]
    let remainingIds: [String]
    let onComplete: ([String], [String]) -> Void

    @State private var sharedDecision = true
    @State private var reviewedDecision = false
    @State private var skipShared = false
    @State private var skipReviewed = false

    var body: some View {
        NavigationStack {
            Form {
                Section("選択した写真") {
                    Toggle("\(selectedIds.count)件を共有済みにする", isOn: $sharedDecision)
                    Toggle("次回から確認しない", isOn: $skipShared)
                }

                Section("残りの写真") {
                    Toggle("\(remainingIds.count)件を確認済みにする", isOn: $reviewedDecision)
                    Text("確認済みにすると未処理一覧へ表示されなくなります。直近の操作から取り消せます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Toggle("次回から確認しない", isOn: $skipReviewed)
                }
            }
            .navigationTitle("共有を終えましたか？")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        store.setSkipSharedConfirmation(skipShared)
                        store.setSkipReviewedConfirmation(skipReviewed)
                        onComplete(
                            sharedDecision ? selectedIds : [],
                            reviewedDecision ? remainingIds : []
                        )
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("あとで") {
                        onComplete([], [])
                    }
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
                    Toggle("共有済み確認を省略", isOn: Binding(
                        get: { store.skipSharedConfirmation },
                        set: { store.setSkipSharedConfirmation($0) }
                    ))
                    Toggle("確認済み確認を省略", isOn: Binding(
                        get: { store.skipReviewedConfirmation },
                        set: { store.setSkipReviewedConfirmation($0) }
                    ))
                }

                Section("権限") {
                    Text("写真ライブラリ: \(String(describing: photoService.authorizationStatus))")
                }

                Section("アプリ情報") {
                    Text("ShareCheck")
                    Text("Version 1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
        }
    }
}
