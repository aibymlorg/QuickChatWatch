import SwiftUI
import SwiftData
import WatchKit
import UserNotifications

@main
struct AIQuickChatWatchApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
                .onAppear {
                    // Set model context for instruction handler
                    InstructionHandler.shared.modelContext = modelContainer.mainContext

                    // Register for push notifications
                    Task {
                        await PushNotificationService.shared.registerForPushNotifications()
                    }

                    // Schedule background refresh
                    BackgroundTaskService.shared.scheduleBackgroundRefresh()
                }
        }
    }
}

// MARK: - App Delegate for Push Notifications & Background Tasks

class AppDelegate: NSObject, WKApplicationDelegate {

    // MARK: - Push Notification Registration

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        Task { @MainActor in
            PushNotificationService.shared.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
        }
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        Task { @MainActor in
            PushNotificationService.shared.didFailToRegisterForRemoteNotifications(withError: error)
        }
    }

    // MARK: - Handle Push Notifications

    func didReceiveRemoteNotification(
        _ userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (WKBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            PushNotificationService.shared.handleBackgroundNotification(userInfo, completion: completionHandler)
        }
    }

    // MARK: - Background Tasks

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Handle background app refresh
                Task { @MainActor in
                    await BackgroundTaskService.shared.handleBackgroundRefresh()
                    backgroundTask.setTaskCompletedWithSnapshot(false)
                }

            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Handle snapshot refresh
                Task { @MainActor in
                    BackgroundTaskService.shared.handleSnapshotRefresh(snapshotTask)
                }

            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Handle URL session completion
                Task { @MainActor in
                    BackgroundTaskService.shared.handleURLSessionTask(urlSessionTask)
                }

            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Handle Watch Connectivity data
                connectivityTask.setTaskCompletedWithSnapshot(false)

            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching() {
        // Setup notification center delegate
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationDidBecomeActive() {
        // Trigger sync when app becomes active
        NotificationCenter.default.post(name: .syncRequested, object: nil)
    }

    func applicationWillResignActive() {
        // Schedule background refresh when going to background
        Task { @MainActor in
            BackgroundTaskService.shared.scheduleBackgroundRefresh()
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        Task { @MainActor in
            PushNotificationService.shared.handleNotification(userInfo)
        }

        // Show banner even when in foreground
        completionHandler([.banner, .sound])
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        Task { @MainActor in
            PushNotificationService.shared.handleNotification(userInfo)
        }

        completionHandler()
    }
}
