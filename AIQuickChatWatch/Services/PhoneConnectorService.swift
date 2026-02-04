import Foundation
import WatchConnectivity
import Combine

/// Service for receiving context from iPhone companion app
@MainActor
final class PhoneConnectorService: NSObject, ObservableObject {
    static let shared = PhoneConnectorService()

    @Published var isPhoneReachable: Bool = false
    @Published var lastReceivedContext: ReceivedContext?
    @Published var receivedPhrases: [String] = []

    private var session: WCSession?
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        guard WCSession.isSupported() else { return }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Request Context from iPhone

    /// Request current context from iPhone
    func requestContext() {
        guard let session = session, session.isReachable else { return }

        session.sendMessage(["type": "request_context"], replyHandler: nil) { error in
            print("Failed to request context: \(error)")
        }
    }

    /// Report phrase spoken to iPhone (for analytics)
    func reportPhraseSpoken(_ phrase: String) {
        guard let session = session else { return }

        let message: [String: Any] = [
            "type": "phrase_spoken",
            "phrase": phrase,
            "timestamp": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectorService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
        }
    }

    // Receive real-time messages
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.handleMessage(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            self.handleMessage(message)
            replyHandler(["status": "received"])
        }
    }

    // Receive background transfers
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            self.handleMessage(userInfo)
        }
    }

    // MARK: - Message Handling

    @MainActor
    private func handleMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "context_update":
            handleContextUpdate(message)

        case "custom_phrases":
            handleCustomPhrases(message)

        default:
            print("Unknown message type: \(type)")
        }
    }

    @MainActor
    private func handleContextUpdate(_ message: [String: Any]) {
        guard let environmentType = message["environmentType"] as? String,
              let confidence = message["confidence"] as? Double,
              let source = message["source"] as? String,
              let phrases = message["phrases"] as? [String] else {
            return
        }

        let context = ReceivedContext(
            environmentType: environmentType,
            confidence: confidence,
            source: source,
            placeName: message["placeName"] as? String,
            sceneDescription: message["sceneDescription"] as? String,
            timestamp: Date()
        )

        lastReceivedContext = context
        receivedPhrases = phrases

        // Notify the app to update phrases
        NotificationCenter.default.post(
            name: .phoneContextReceived,
            object: nil,
            userInfo: [
                "context": context,
                "phrases": phrases
            ]
        )

        // Haptic feedback
        HapticManager.shared.notification()
    }

    @MainActor
    private func handleCustomPhrases(_ message: [String: Any]) {
        guard let phrases = message["phrases"] as? [String],
              let scenario = message["scenario"] as? String else {
            return
        }

        receivedPhrases = phrases

        NotificationCenter.default.post(
            name: .phrasesReceived,
            object: nil,
            userInfo: ["phrases": phrases, "scenario": scenario]
        )

        HapticManager.shared.notification()
    }
}

// MARK: - Received Context Model

struct ReceivedContext {
    let environmentType: String
    let confidence: Double
    let source: String
    let placeName: String?
    let sceneDescription: String?
    let timestamp: Date

    var displayName: String {
        switch environmentType {
        case "hospital": return "Hospital"
        case "clinic": return "Clinic"
        case "pharmacy": return "Pharmacy"
        case "restaurant": return "Restaurant"
        case "cafe": return "Cafe"
        case "grocery": return "Grocery"
        case "retail": return "Shopping"
        case "bank": return "Bank"
        case "publicTransport": return "Transit"
        case "airport": return "Airport"
        case "school": return "School"
        case "office": return "Office"
        case "home": return "Home"
        case "outdoors": return "Outdoors"
        case "gym": return "Gym"
        case "emergency": return "Emergency"
        default: return "General"
        }
    }

    var icon: String {
        switch environmentType {
        case "hospital", "clinic": return "cross.case.fill"
        case "pharmacy": return "pills.fill"
        case "restaurant": return "fork.knife"
        case "cafe": return "cup.and.saucer.fill"
        case "grocery": return "cart.fill"
        case "retail": return "bag.fill"
        case "bank": return "building.columns.fill"
        case "publicTransport": return "bus.fill"
        case "airport": return "airplane"
        case "school": return "graduationcap.fill"
        case "office": return "briefcase.fill"
        case "home": return "house.fill"
        case "outdoors": return "tree.fill"
        case "gym": return "figure.run"
        case "emergency": return "exclamationmark.triangle.fill"
        default: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let phoneContextReceived = Notification.Name("phoneContextReceived")
}
