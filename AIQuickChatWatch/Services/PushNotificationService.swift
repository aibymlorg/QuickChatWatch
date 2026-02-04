import Foundation
import UserNotifications
import WatchKit

/// Service for handling push notifications and remote instructions
@MainActor
final class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    @Published private(set) var deviceToken: String?
    @Published private(set) var lastInstruction: RemoteInstruction?
    @Published private(set) var isRegistered: Bool = false

    /// Callback when new instruction is received
    var onInstructionReceived: ((RemoteInstruction) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Registration

    /// Request notification permissions and register for push
    func registerForPushNotifications() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])

            if granted {
                await MainActor.run {
                    WKApplication.shared().registerForRemoteNotifications()
                }
                print("Push notification permission granted")
            } else {
                print("Push notification permission denied")
            }
        } catch {
            print("Failed to request notification permission: \(error)")
        }
    }

    /// Called when device token is received
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        self.isRegistered = true

        print("Device token: \(tokenString)")

        // Send token to server
        Task {
            await sendDeviceTokenToServer(tokenString)
        }
    }

    /// Called when registration fails
    func didFailToRegisterForRemoteNotifications(withError error: Error) {
        print("Failed to register for remote notifications: \(error)")
        isRegistered = false
    }

    // MARK: - Handle Incoming Notifications

    /// Process incoming push notification
    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        print("Received push notification: \(userInfo)")

        guard let instruction = RemoteInstruction.from(userInfo: userInfo) else {
            print("Failed to parse instruction from notification")
            return
        }

        lastInstruction = instruction
        onInstructionReceived?(instruction)

        // Process the instruction
        Task {
            await processInstruction(instruction)
        }
    }

    /// Handle notification when app is in background
    func handleBackgroundNotification(
        _ userInfo: [AnyHashable: Any],
        completion: @escaping (WKBackgroundFetchResult) -> Void
    ) {
        guard let instruction = RemoteInstruction.from(userInfo: userInfo) else {
            completion(.noData)
            return
        }

        lastInstruction = instruction

        Task {
            await processInstruction(instruction)
            completion(.newData)
        }
    }

    // MARK: - Process Instructions

    private func processInstruction(_ instruction: RemoteInstruction) async {
        HapticManager.shared.notification()

        switch instruction.type {
        case .syncPhrases:
            // Trigger phrase sync
            NotificationCenter.default.post(name: .syncRequested, object: nil)

        case .loadContextPack:
            // Generate and load new context pack
            if let scenario = instruction.payload?["scenario"] as? String {
                NotificationCenter.default.post(
                    name: .contextPackRequested,
                    object: nil,
                    userInfo: ["scenario": scenario]
                )
            }

        case .updatePhrases:
            // Direct phrase update
            if let phrases = instruction.payload?["phrases"] as? [String] {
                NotificationCenter.default.post(
                    name: .phrasesReceived,
                    object: nil,
                    userInfo: ["phrases": phrases]
                )
            }

        case .speakMessage:
            // Speak a message immediately
            if let message = instruction.payload?["message"] as? String {
                NotificationCenter.default.post(
                    name: .speakRequested,
                    object: nil,
                    userInfo: ["message": message]
                )
            }

        case .updateSettings:
            // Update settings remotely
            NotificationCenter.default.post(name: .settingsUpdateRequested, object: nil)

        case .emergency:
            // Emergency phrase activation
            HapticManager.shared.notification()
            HapticManager.shared.notification()
            NotificationCenter.default.post(name: .emergencyActivated, object: nil)
        }
    }

    // MARK: - Server Communication

    private func sendDeviceTokenToServer(_ token: String) async {
        do {
            try await APIClient.shared.registerDeviceToken(token)
            print("Device token registered with server")
        } catch {
            print("Failed to register device token: \(error)")
        }
    }
}

// MARK: - Remote Instruction Model

struct RemoteInstruction: Identifiable {
    let id: UUID
    let type: InstructionType
    let payload: [String: Any]?
    let timestamp: Date
    let sender: String?

    enum InstructionType: String {
        case syncPhrases = "sync_phrases"
        case loadContextPack = "load_context_pack"
        case updatePhrases = "update_phrases"
        case speakMessage = "speak_message"
        case updateSettings = "update_settings"
        case emergency = "emergency"
    }

    static func from(userInfo: [AnyHashable: Any]) -> RemoteInstruction? {
        guard let aps = userInfo["aps"] as? [String: Any],
              let data = userInfo["data"] as? [String: Any],
              let typeString = data["type"] as? String,
              let type = InstructionType(rawValue: typeString) else {
            return nil
        }

        return RemoteInstruction(
            id: UUID(),
            type: type,
            payload: data["payload"] as? [String: Any],
            timestamp: Date(),
            sender: data["sender"] as? String
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let syncRequested = Notification.Name("syncRequested")
    static let contextPackRequested = Notification.Name("contextPackRequested")
    static let phrasesReceived = Notification.Name("phrasesReceived")
    static let speakRequested = Notification.Name("speakRequested")
    static let settingsUpdateRequested = Notification.Name("settingsUpdateRequested")
    static let emergencyActivated = Notification.Name("emergencyActivated")
}
