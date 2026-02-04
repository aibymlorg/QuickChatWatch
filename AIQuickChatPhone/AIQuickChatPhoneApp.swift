import SwiftUI
import WatchConnectivity

@main
struct AIQuickChatPhoneApp: App {
    @StateObject private var watchConnector = WatchConnectorService.shared
    @StateObject private var environmentDetector = EnvironmentDetectionService.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(watchConnector)
                .environmentObject(environmentDetector)
                .onAppear {
                    // Start environment detection
                    environmentDetector.startMonitoring()
                }
        }
    }
}
