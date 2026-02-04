import Foundation
import SwiftData

@Model
final class UsageLog {
    @Attribute(.unique) var id: UUID
    var eventType: String
    var eventData: String?
    var phraseUsed: String?
    var sessionId: String?
    var syncStatusRaw: String
    var createdAt: Date

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingUpload }
        set { syncStatusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        eventType: String,
        eventData: String? = nil,
        phraseUsed: String? = nil,
        sessionId: String? = nil,
        syncStatus: SyncStatus = .pendingUpload,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.eventType = eventType
        self.eventData = eventData
        self.phraseUsed = phraseUsed
        self.sessionId = sessionId
        self.syncStatusRaw = syncStatus.rawValue
        self.createdAt = createdAt
    }

    /// Common event types
    enum EventType: String {
        case phraseSpoken = "phrase_spoken"
        case customTextSpoken = "custom_text_spoken"
        case contextPackGenerated = "context_pack_generated"
        case settingsChanged = "settings_changed"
        case appOpened = "app_opened"
        case appClosed = "app_closed"
        case syncCompleted = "sync_completed"
        case errorOccurred = "error_occurred"
    }

    /// Create a log entry for a spoken phrase
    static func phraseSpoken(_ phrase: String, sessionId: String?) -> UsageLog {
        UsageLog(
            eventType: EventType.phraseSpoken.rawValue,
            phraseUsed: phrase,
            sessionId: sessionId
        )
    }

    /// Create a log entry for custom text
    static func customTextSpoken(_ text: String, sessionId: String?) -> UsageLog {
        UsageLog(
            eventType: EventType.customTextSpoken.rawValue,
            phraseUsed: text,
            sessionId: sessionId
        )
    }

    /// Create a log entry for errors
    static func error(_ message: String, sessionId: String?) -> UsageLog {
        UsageLog(
            eventType: EventType.errorOccurred.rawValue,
            eventData: message,
            sessionId: sessionId
        )
    }

    /// Convert to API request
    func toDTO() -> LogEventRequest {
        LogEventRequest(
            eventType: eventType,
            eventData: eventData,
            phraseUsed: phraseUsed,
            sessionId: sessionId
        )
    }
}
