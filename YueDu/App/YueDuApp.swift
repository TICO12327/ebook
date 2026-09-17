import SwiftData
import SwiftUI

@main
struct YueDuApp: App {
    @State private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settingsStore)
        }
        .modelContainer(for: Book.self)
    }
}
