import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        TabView {
            BookshelfView()
                .tabItem {
                    Label("书架", systemImage: "books.vertical")
                }

            StoreView()
                .tabItem {
                    Label("书城", systemImage: "sparkles")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .task {
            await settingsStore.prepare()
        }
    }
}
