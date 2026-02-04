import Foundation
import WatchConnectivity
import Combine

/// Service for communicating with Apple Watch
class WatchConnectorService: NSObject, ObservableObject {
    static let shared = WatchConnectorService()

    @Published var isWatchAppInstalled: Bool = false
    @Published var isReachable: Bool = false
    @Published var isWatchPaired: Bool = false
    @Published var lastSentContext: EnvironmentContext?
    @Published var lastError: String?

    /// Alias for consistency
    var isWatchReachable: Bool { isReachable }

    private var session: WCSession?

    private override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Send Context to Watch

    /// Send environment context to Apple Watch
    func sendContext(_ context: EnvironmentContext) {
        guard let session = session else {
            lastError = "WatchConnectivity not available"
            return
        }

        guard session.activationState == .activated else {
            lastError = "Watch session not activated"
            return
        }

        let message = WatchContextMessage(environment: context)
        let messageDict = message.toDictionary()

        // Try interactive message first (if watch is reachable)
        if session.isReachable {
            session.sendMessage(messageDict, replyHandler: { reply in
                print("Watch acknowledged context: \(reply)")
                DispatchQueue.main.async {
                    self.lastSentContext = context
                    self.lastError = nil
                }
            }, errorHandler: { error in
                print("Failed to send message: \(error)")
                // Fall back to transferUserInfo
                self.transferContext(messageDict)
            })
        } else {
            // Watch not reachable, use background transfer
            transferContext(messageDict)
        }
    }

    private func transferContext(_ messageDict: [String: Any]) {
        guard let session = session else { return }

        // Use transferUserInfo for background delivery
        session.transferUserInfo(messageDict)

        DispatchQueue.main.async {
            self.lastError = nil
        }
    }

    /// Send emergency alert to watch
    func sendEmergencyAlert() {
        let emergencyContext = EnvironmentContext(
            type: .emergency,
            confidence: 1.0,
            source: .manual,
            timestamp: Date(),
            details: nil
        )
        sendContext(emergencyContext)
    }

    /// Send custom phrases to watch
    func sendCustomPhrases(_ phrases: [String], for scenario: String) {
        guard let session = session, session.isReachable else {
            // Use transferUserInfo if not reachable
            let message: [String: Any] = [
                "type": "custom_phrases",
                "scenario": scenario,
                "phrases": phrases,
                "timestamp": Date().timeIntervalSince1970
            ]
            session?.transferUserInfo(message)
            return
        }

        let message: [String: Any] = [
            "type": "custom_phrases",
            "scenario": scenario,
            "phrases": phrases,
            "timestamp": Date().timeIntervalSince1970
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send custom phrases: \(error)")
        }
    }

    /// Send custom phrases to watch (alternative signature)
    func sendCustomPhrases(_ phrases: [String], scenario: String) {
        sendCustomPhrases(phrases, for: scenario)
    }

    /// Send context with explicit phrases to watch
    func sendContextToWatch(_ context: EnvironmentContext, phrases: [String]) {
        guard let session = session else {
            lastError = "WatchConnectivity not available"
            return
        }

        let message: [String: Any] = [
            "type": "context_update",
            "environmentType": context.type.rawValue,
            "confidence": context.confidence,
            "source": context.source.rawValue,
            "phrases": phrases,
            "placeName": context.details?.placeName ?? "",
            "sceneDescription": context.details?.sceneDescription ?? "",
            "timestamp": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: { reply in
                print("Watch acknowledged context with phrases")
            }, errorHandler: { error in
                print("Failed to send context with phrases: \(error)")
                session.transferUserInfo(message)
            })
        } else {
            session.transferUserInfo(message)
        }
    }

    /// Request current status from watch
    func requestWatchStatus() {
        guard let session = session, session.isReachable else { return }

        session.sendMessage(["type": "status_request"], replyHandler: { reply in
            print("Watch status: \(reply)")
        }, errorHandler: { error in
            print("Failed to get watch status: \(error)")
        })
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectorService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
            self.isWatchPaired = session.isPaired

            if let error = error {
                self.lastError = error.localizedDescription
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = false
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate session
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    // Receive messages from watch
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleWatchMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleWatchMessage(message)
        replyHandler(["status": "received"])
    }

    private func handleWatchMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "request_context":
            // Watch is requesting current context
            if let context = EnvironmentDetectionService.shared.currentContext {
                sendContext(context)
            }

        case "phrase_spoken":
            // Watch reported a phrase was spoken
            if let phrase = message["phrase"] as? String {
                print("User spoke: \(phrase)")
                // Could log analytics here
            }

        default:
            print("Unknown message type: \(type)")
        }
    }
}
