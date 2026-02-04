import Foundation
import SwiftData

@Model
final class Phrase {
    @Attribute(.unique) var id: UUID
    var phraseText: String
    var category: String?
    var usageCount: Int
    var isFavorite: Bool
    var syncStatusRaw: String
    var serverID: String?
    var createdAt: Date
    var updatedAt: Date

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingUpload }
        set { syncStatusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        phraseText: String,
        category: String? = nil,
        usageCount: Int = 0,
        isFavorite: Bool = false,
        syncStatus: SyncStatus = .pendingUpload,
        serverID: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.phraseText = phraseText
        self.category = category
        self.usageCount = usageCount
        self.isFavorite = isFavorite
        self.syncStatusRaw = syncStatus.rawValue
        self.serverID = serverID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Create a Phrase from a server DTO
    static func fromDTO(_ dto: PhraseDTO) -> Phrase {
        Phrase(
            phraseText: dto.phraseText,
            category: dto.category,
            usageCount: dto.usageCount,
            isFavorite: dto.isFavorite,
            syncStatus: .synced,
            serverID: dto.id,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    /// Update this phrase from a server DTO
    func updateFromDTO(_ dto: PhraseDTO) {
        self.phraseText = dto.phraseText
        self.category = dto.category
        self.usageCount = dto.usageCount
        self.isFavorite = dto.isFavorite
        self.serverID = dto.id
        self.updatedAt = dto.updatedAt
        self.syncStatus = .synced
    }

    /// Convert to DTO for API requests
    func toCreateDTO() -> CreatePhraseRequest {
        CreatePhraseRequest(phraseText: phraseText, category: category)
    }

    func toUpdateDTO() -> UpdatePhraseRequest {
        UpdatePhraseRequest(
            phraseText: phraseText,
            category: category,
            usageCount: usageCount,
            isFavorite: isFavorite
        )
    }
}
