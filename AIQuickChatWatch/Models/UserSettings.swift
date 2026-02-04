import Foundation
import SwiftData

@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID
    var language: String
    var voiceSpeed: Double
    var aiEnabled: Bool
    var responseMode: String
    var syncStatusRaw: String
    var updatedAt: Date

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingUpload }
        set { syncStatusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        language: String = "English",
        voiceSpeed: Double = 1.0,
        aiEnabled: Bool = true,
        responseMode: String = "general",
        syncStatus: SyncStatus = .pendingUpload,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.language = language
        self.voiceSpeed = voiceSpeed
        self.aiEnabled = aiEnabled
        self.responseMode = responseMode
        self.syncStatusRaw = syncStatus.rawValue
        self.updatedAt = updatedAt
    }

    /// Supported languages with their locale codes
    static let supportedLanguages: [(name: String, code: String)] = [
        ("English", "en-US"),
        ("Spanish", "es-ES"),
        ("French", "fr-FR"),
        ("German", "de-DE"),
        ("Italian", "it-IT"),
        ("Portuguese", "pt-BR"),
        ("Hindi", "hi-IN"),
        ("Tamil", "ta-IN"),
        ("Telugu", "te-IN"),
        ("Bengali", "bn-IN"),
        ("Arabic", "ar-SA"),
        ("Mandarin Chinese", "zh-CN"),
        ("Cantonese", "zh-HK"),
        ("Japanese", "ja-JP"),
        ("Korean", "ko-KR")
    ]

    /// Response mode options
    static let responseModes: [(name: String, description: String)] = [
        ("general", "General use"),
        ("public_transport", "Public Transport"),
        ("shopping", "Shopping / Retail"),
        ("school", "School / Campus"),
        ("hospital", "Hospital Ward"),
        ("office", "Office Meeting"),
        ("custom", "Custom Scenario")
    ]

    /// Get locale code for current language
    var languageCode: String {
        Self.supportedLanguages.first { $0.name == language }?.code ?? "en-US"
    }

    /// Convert to dictionary for API sync
    func toDictionary() -> [String: Any] {
        [
            "language": language,
            "voiceSpeed": voiceSpeed,
            "aiEnabled": aiEnabled,
            "responseMode": responseMode
        ]
    }

    /// Update from server settings
    func updateFromServer(_ settings: SettingsDTO) {
        if let lang = settings.language {
            self.language = lang
        }
        if let speed = settings.voiceSpeed {
            self.voiceSpeed = speed
        }
        if let ai = settings.aiEnabled {
            self.aiEnabled = ai
        }
        if let mode = settings.responseMode {
            self.responseMode = mode
        }
        self.syncStatus = .synced
        self.updatedAt = Date()
    }
}
