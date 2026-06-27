import SwiftUI

@main
struct ShareCheckApp: App {
    @StateObject private var store = ShareCheckStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
