import Foundation
import SwiftData
import Combine

/// Centralized handler for processing remote instructions
@MainActor
final class InstructionHandler: ObservableObject {
    static let shared = InstructionHandler()

    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var lastProcessedInstruction: String?

    private var cancellables = Set<AnyCancellable>()
    weak var modelContext: ModelContext?

    private init() {
        setupObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Sync requested
        NotificationCenter.default.publisher(for: .syncRequested)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleSyncRequest()
                }
            }
            .store(in: &cancellables)

        // Context pack requested
        NotificationCenter.default.publisher(for: .contextPackRequested)
            .sink { [weak self] notification in
                if let scenario = notification.userInfo?["scenario"] as? String {
                    Task { @MainActor in
                        await self?.handleContextPackRequest(scenario: scenario)
                    }
                }
            }
            .store(in: &cancellables)

        // Phrases received directly
        NotificationCenter.default.publisher(for: .phrasesReceived)
            .sink { [weak self] notification in
                if let phrases = notification.userInfo?["phrases"] as? [String] {
                    Task { @MainActor in
                        await self?.handlePhrasesReceived(phrases)
                    }
                }
            }
            .store(in: &cancellables)

        // Speak message requested
        NotificationCenter.default.publisher(for: .speakRequested)
            .sink { [weak self] notification in
                if let message = notification.userInfo?["message"] as? String {
                    Task { @MainActor in
                        await self?.handleSpeakRequest(message: message)
                    }
                }
            }
            .store(in: &cancellables)

        // Settings update requested
        NotificationCenter.default.publisher(for: .settingsUpdateRequested)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleSettingsUpdateRequest()
                }
            }
            .store(in: &cancellables)

        // Emergency activated
        NotificationCenter.default.publisher(for: .emergencyActivated)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleEmergency()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Instruction Handlers

    private func handleSyncRequest() async {
        guard let context = modelContext else { return }

        isProcessing = true
        lastProcessedInstruction = "Syncing..."

        await SyncService.shared.syncNow(context: context)

        isProcessing = false
        lastProcessedInstruction = "Sync complete"
        HapticManager.shared.success()
    }

    private func handleContextPackRequest(scenario: String) async {
        isProcessing = true
        lastProcessedInstruction = "Loading context: \(scenario)"

        do {
            let phrases = try await GeminiService.shared.generateContextPack(scenario: scenario)
            await handlePhrasesReceived(phrases)

            lastProcessedInstruction = "Loaded: \(scenario)"
            HapticManager.shared.success()
        } catch {
            print("Failed to generate context pack: \(error)")
            HapticManager.shared.failure()
        }

        isProcessing = false
    }

    private func handlePhrasesReceived(_ phraseTexts: [String]) async {
        guard let context = modelContext else { return }

        isProcessing = true
        lastProcessedInstruction = "Updating phrases..."

        // Mark existing non-favorite phrases for deletion
        let descriptor = FetchDescriptor<Phrase>(
            predicate: #Predicate { $0.syncStatusRaw != "pendingDelete" && !$0.isFavorite }
        )

        do {
            let existingPhrases = try context.fetch(descriptor)
            for phrase in existingPhrases {
                phrase.syncStatus = .pendingDelete
            }

            // Create new phrases
            for text in phraseTexts.prefix(8) {
                let phrase = Phrase(phraseText: text)
                context.insert(phrase)
            }

            try context.save()

            lastProcessedInstruction = "Phrases updated"
            HapticManager.shared.success()

            // Notify UI to refresh
            NotificationCenter.default.post(name: .phrasesUpdated, object: nil)
        } catch {
            print("Failed to update phrases: \(error)")
            HapticManager.shared.failure()
        }

        isProcessing = false
    }

    private func handleSpeakRequest(message: String) async {
        lastProcessedInstruction = "Speaking..."
        await TTSService.shared.speak(message)
        lastProcessedInstruction = "Spoke: \(message)"
    }

    private func handleSettingsUpdateRequest() async {
        guard let context = modelContext else { return }

        isProcessing = true
        lastProcessedInstruction = "Updating settings..."

        do {
            let serverSettings = try await APIClient.shared.getSettings()

            let descriptor = FetchDescriptor<UserSettings>()
            let settings = try context.fetch(descriptor)

            if let localSettings = settings.first {
                localSettings.updateFromServer(serverSettings)
                try context.save()
            }

            lastProcessedInstruction = "Settings updated"
            HapticManager.shared.success()
        } catch {
            print("Failed to update settings: \(error)")
            HapticManager.shared.failure()
        }

        isProcessing = false
    }

    private func handleEmergency() async {
        // Load emergency phrases
        let emergencyPhrases = [
            "Help me!",
            "Call 911",
            "I need help now",
            "Emergency",
            "Get a doctor",
            "I'm not okay",
            "Please help",
            "Urgent"
        ]

        await handlePhrasesReceived(emergencyPhrases)

        // Speak first phrase
        await TTSService.shared.speak("Help me!")

        lastProcessedInstruction = "Emergency mode"
    }
}

// MARK: - Additional Notification Names

extension Notification.Name {
    static let phrasesUpdated = Notification.Name("phrasesUpdated")
}
