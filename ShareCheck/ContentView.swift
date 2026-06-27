import SwiftUI
import Photos

struct ContentView: View {
    @EnvironmentObject private var store: ShareCheckStore
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
            guard !isUITesting else { return }
            await photoService.requestAuthorizationIfNeeded()
            photoService.loadItems(startDate: store.managementStartDate, store: store)
        }
        .onChange(of: store.statuses) { _, _ in
            guard !isUITesting else { return }
            photoService.loadItems(startDate: store.managementStartDate, store: store)
        }
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
                        Text("未処理").font(.headline)
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(counts.total)").font(.system(size: 48, weight: .bold, design: .rounded)).foregroundStyle(counts.total == 0 ? .green : .blue)
                            Text("件").font(.title3)
                            if counts.total == 0 { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                        }
                    }.padding(.vertical, 8)
                }
                Section("内訳") {
                    row("今日", counts.today)
                    row("昨日", counts.yesterday)
                    row("今週", counts.thisWeek)
                    row("それ以前", counts.older)
                }
                if let latest = store.latestOperation {
                    Section("直近の操作") {
                        row("共有済み", latest.sharedIds.count)
                        row("確認済み", latest.reviewedIds.count)
                        Button(role: .destructive) { store.undoLatestOperation() } label: { Label("元に戻す", systemImage: "arrow.uturn.backward") }
                    }
                }
            }.navigationTitle("ShareCheck")
        }
    }
    private func row(_ title: String, _ count: Int) -> some View { HStack { Text(title); Spacer(); Text("\(count)件") } }
}

struct PendingGridView: View {
    @EnvironmentObject private var store: ShareCheckStore
    @ObservedObject var photoService: PhotoLibraryService
    @State private var selectedIds: Set<String> = []
    @State private var showPostShareConfirmation = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(photoService.items) { item in
                        ThumbnailView(asset: item.asset, isSelected: selectedIds.contains(item.id))
                            .onTapGesture { toggle(item.id) }
                    }
                }
            }
            .navigationTitle("未処理")
            .toolbar { Button("共有") { showPostShareConfirmation = true }.disabled(selectedIds.isEmpty) }
            .sheet(isPresented: $showPostShareConfirmation) {
                PostShareConfirmationView(selectedIds: Array(selectedIds), remainingIds: photoService.items.map(\.id).filter { !selectedIds.contains($0) }) { sharedIds, reviewedIds in
                    store.mark(sharedIds: sharedIds, reviewedIds: reviewedIds)
                    selectedIds.removeAll()
                    showPostShareConfirmation = false
                }
            }
        }
    }
    private func toggle(_ id: String) { if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) } }
}

struct ThumbnailView: View {
    let asset: PHAsset
    let isSelected: Bool
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle().fill(.quaternary).aspectRatio(1, contentMode: .fit)
            if isSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue).padding(4) }
        }
    }
}

struct PostShareConfirmationView: View {
    @EnvironmentObject private var store: ShareCheckStore
    let selectedIds: [String]
    let remainingIds: [String]
    let onComplete: ([String], [String]) -> Void
    @State private var sharedDecision = true
    @State private var reviewedDecision = false

    var body: some View {
        NavigationStack {
            Form {
                Section("選択した写真") { Toggle("\(selectedIds.count)件を共有済みにする", isOn: $sharedDecision) }
                Section("残りの写真") { Toggle("\(remainingIds.count)件を確認済みにする", isOn: $reviewedDecision) }
            }
            .navigationTitle("共有を終えましたか？")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完了") { onComplete(sharedDecision ? selectedIds : [], reviewedDecision ? remainingIds : []) } }
                ToolbarItem(placement: .cancellationAction) { Button("あとで") { onComplete([], []) } }
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
                Section("管理設定") { Button(role: .destructive) { store.resetManagementStartDate() } label: { Text("管理開始日時をリセット") } }
                Section("確認") {
                    Toggle("共有済み確認を省略", isOn: Binding(get: { store.skipSharedConfirmation }, set: { store.setSkipSharedConfirmation($0) }))
                    Toggle("確認済み確認を省略", isOn: Binding(get: { store.skipReviewedConfirmation }, set: { store.setSkipReviewedConfirmation($0) }))
                }
                Section("アプリ情報") { Text("ShareCheck"); Text("Version 1.0.0").foregroundStyle(.secondary) }
            }.navigationTitle("設定")
        }
    }
}
