import SwiftUI
import SwiftData

@main
struct AIQuickChatWatchApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                Phrase.self,
                UserSettings.self,
                UsageLog.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
    }
}
