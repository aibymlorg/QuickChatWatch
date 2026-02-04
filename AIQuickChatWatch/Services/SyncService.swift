import Foundation
import SwiftData
import Combine

/// Service for synchronizing local data with the server
@MainActor
final class SyncService: ObservableObject {
    static let shared = SyncService()

    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var pendingChanges: Int = 0

    private let reachability = ReachabilityService.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Auto-sync when network becomes available
        reachability.$isConnected
            .removeDuplicates()
            .filter { $0 }
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.syncAll(context: nil)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Full Sync

    /// Sync all data with server
    func syncAll(context: ModelContext?) async {
        guard let context = context else { return }
        guard !isSyncing else { return }
        guard reachability.isConnected else { return }

        isSyncing = true
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        do {
            // Sync in order: upload local changes first, then download server changes
            try await syncPhrases(context: context)
            try await syncSettings(context: context)
            try await syncAnalytics(context: context)

            await updatePendingChangesCount(context: context)
            HapticManager.shared.success()
        } catch {
            print("Sync failed: \(error)")
            HapticManager.shared.failure()
        }
    }

    // MARK: - Phrase Sync

    private func syncPhrases(context: ModelContext) async throws {
        // 1. Upload pending new phrases
        let pendingUpload = try fetchPhrases(context: context, status: .pendingUpload)
        for phrase in pendingUpload {
            do {
                let serverPhrase = try await APIClient.shared.createPhrase(
                    phraseText: phrase.phraseText,
                    category: phrase.category
                )
                phrase.serverID = serverPhrase.id
                phrase.syncStatus = .synced
            } catch {
                print("Failed to upload phrase: \(error)")
            }
        }

        // 2. Upload pending updates
        let pendingUpdate = try fetchPhrases(context: context, status: .pendingUpdate)
        for phrase in pendingUpdate {
            guard let serverID = phrase.serverID else { continue }
            do {
                _ = try await APIClient.shared.updatePhrase(
                    id: serverID,
                    updates: phrase.toUpdateDTO()
                )
                phrase.syncStatus = .synced
            } catch {
                print("Failed to update phrase: \(error)")
            }
        }

        // 3. Delete pending deletes on server
        let pendingDelete = try fetchPhrases(context: context, status: .pendingDelete)
        for phrase in pendingDelete {
            if let serverID = phrase.serverID {
                do {
                    try await APIClient.shared.deletePhrase(id: serverID)
                } catch {
                    print("Failed to delete phrase on server: \(error)")
                }
            }
            context.delete(phrase)
        }

        // 4. Download server phrases
        let serverPhrases = try await APIClient.shared.getPhrases()
        let localPhrases = try fetchAllPhrases(context: context)
        let localServerIDs = Set(localPhrases.compactMap { $0.serverID })

        for serverPhrase in serverPhrases {
            if localServerIDs.contains(serverPhrase.id) {
                // Update existing phrase if server is newer
                if let localPhrase = localPhrases.first(where: { $0.serverID == serverPhrase.id }),
                   localPhrase.syncStatus == .synced,
                   serverPhrase.updatedAt > localPhrase.updatedAt {
                    localPhrase.updateFromDTO(serverPhrase)
                }
            } else {
                // Create new local phrase from server
                let newPhrase = Phrase.fromDTO(serverPhrase)
                context.insert(newPhrase)
            }
        }

        try context.save()
    }

    // MARK: - Settings Sync

    private func syncSettings(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<UserSettings>()
        let settings = try context.fetch(descriptor)

        guard let localSettings = settings.first else { return }

        if localSettings.syncStatus == .pendingUpdate {
            // Upload local settings
            let settingsDTO = SettingsDTO(
                language: localSettings.language,
                voiceSpeed: localSettings.voiceSpeed,
                aiEnabled: localSettings.aiEnabled,
                responseMode: localSettings.responseMode
            )
            _ = try await APIClient.shared.updateSettings(settingsDTO)
            localSettings.syncStatus = .synced
        } else {
            // Download server settings
            let serverSettings = try await APIClient.shared.getSettings()
            localSettings.updateFromServer(serverSettings)
        }

        try context.save()
    }

    // MARK: - Analytics Sync

    private func syncAnalytics(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<UsageLog>(
            predicate: #Predicate { $0.syncStatusRaw == "pendingUpload" }
        )
        let pendingLogs = try context.fetch(descriptor)

        // Batch upload logs
        let requests = pendingLogs.map { $0.toDTO() }
        if !requests.isEmpty {
            try await APIClient.shared.logEvents(requests)

            // Mark as synced
            for log in pendingLogs {
                log.syncStatus = .synced
            }

            try context.save()
        }
    }

    // MARK: - Helpers

    private func fetchPhrases(context: ModelContext, status: SyncStatus) throws -> [Phrase] {
        let statusRaw = status.rawValue
        let descriptor = FetchDescriptor<Phrase>(
            predicate: #Predicate { $0.syncStatusRaw == statusRaw }
        )
        return try context.fetch(descriptor)
    }

    private func fetchAllPhrases(context: ModelContext) throws -> [Phrase] {
        let descriptor = FetchDescriptor<Phrase>()
        return try context.fetch(descriptor)
    }

    private func updatePendingChangesCount(context: ModelContext) async {
        do {
            var count = 0
            for status in [SyncStatus.pendingUpload, .pendingUpdate, .pendingDelete] {
                count += try fetchPhrases(context: context, status: status).count
            }
            pendingChanges = count
        } catch {
            pendingChanges = 0
        }
    }

    // MARK: - Manual Sync Trigger

    /// Force sync now (user-initiated)
    func syncNow(context: ModelContext) async {
        HapticManager.shared.tap()
        await syncAll(context: context)
    }
}
