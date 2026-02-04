import Foundation
import SwiftData
import Combine

/// View model for the main phrase grid interface
@MainActor
final class PhraseGridViewModel: ObservableObject {
    @Published var phrases: [Phrase] = []
    @Published var ttsStatus: TTSStatus = .idle
    @Published var isGeneratingPack: Bool = false
    @Published var showKeyboard: Bool = false
    @Published var customText: String = ""
    @Published var error: String?
    @Published var currentContext: ReceivedContext?
    @Published var contextPhrases: [String] = []

    private let ttsService = TTSService.shared
    private let reachability = ReachabilityService.shared
    private let syncService = SyncService.shared
    private let phoneConnector = PhoneConnectorService.shared
    private var cancellables = Set<AnyCancellable>()

    var modelContext: ModelContext?
    private var sessionId: String = UUID().uuidString

    /// Default phrases for new users
    private let defaultPhrases = [
        "I need water",
        "Yes",
        "No",
        "Thank you",
        "Bathroom",
        "Help",
        "Pain level 5",
        "Call nurse"
    ]

    init() {
        setupBindings()
        setupNotificationObservers()
    }

    private func setupBindings() {
        ttsService.$status
            .receive(on: DispatchQueue.main)
            .assign(to: &$ttsStatus)
    }

    private func setupNotificationObservers() {
        // Listen for phrase updates from remote instructions
        NotificationCenter.default.publisher(for: .phrasesUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadPhrases()
                HapticManager.shared.notification()
            }
            .store(in: &cancellables)

        // Listen for sync requests
        NotificationCenter.default.publisher(for: .syncRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.sync()
                }
            }
            .store(in: &cancellables)

        // Listen for speak requests from remote
        NotificationCenter.default.publisher(for: .speakRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let message = notification.userInfo?["message"] as? String {
                    Task { @MainActor [weak self] in
                        await self?.ttsService.speak(message)
                    }
                }
            }
            .store(in: &cancellables)

        // Listen for context pack requests from remote
        NotificationCenter.default.publisher(for: .contextPackRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let scenario = notification.userInfo?["scenario"] as? String {
                    Task { @MainActor [weak self] in
                        await self?.generateContextPack(scenario: scenario)
                    }
                }
            }
            .store(in: &cancellables)

        // Listen for context updates from iPhone
        NotificationCenter.default.publisher(for: .phoneContextReceived)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let context = notification.userInfo?["context"] as? ReceivedContext,
                   let phrases = notification.userInfo?["phrases"] as? [String] {
                    self?.handlePhoneContext(context, phrases: phrases)
                }
            }
            .store(in: &cancellables)

        // Listen for direct phrase updates from iPhone
        NotificationCenter.default.publisher(for: .phrasesReceived)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let phrases = notification.userInfo?["phrases"] as? [String] {
                    self?.updateContextPhrases(phrases)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Phone Context Handling

    private func handlePhoneContext(_ context: ReceivedContext, phrases: [String]) {
        currentContext = context
        contextPhrases = phrases

        // Haptic to alert user of new context
        HapticManager.shared.notification()
    }

    private func updateContextPhrases(_ phrases: [String]) {
        contextPhrases = phrases
        HapticManager.shared.notification()
    }

    /// Speak a context phrase (from iPhone)
    func speakContextPhrase(_ phrase: String) {
        Task {
            await ttsService.speak(phrase)

            // Report to iPhone
            phoneConnector.reportPhraseSpoken(phrase)

            logEvent(.phraseSpoken(phrase, sessionId: sessionId))
        }
    }

    // MARK: - Data Loading

    /// Load phrases from SwiftData
    func loadPhrases() {
        guard let context = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<Phrase>(
                predicate: #Predicate { $0.syncStatusRaw != "pendingDelete" },
                sortBy: [SortDescriptor(\.usageCount, order: .reverse)]
            )
            phrases = try context.fetch(descriptor)

            // If no phrases, create defaults
            if phrases.isEmpty {
                createDefaultPhrases()
            }
        } catch {
            print("Failed to load phrases: \(error)")
            self.error = "Failed to load phrases"
        }
    }

    private func createDefaultPhrases() {
        guard let context = modelContext else { return }

        for text in defaultPhrases {
            let phrase = Phrase(phraseText: text)
            context.insert(phrase)
        }

        do {
            try context.save()
            loadPhrases()
        } catch {
            print("Failed to save default phrases: \(error)")
        }
    }

    // MARK: - TTS

    /// Speak a phrase
    func speak(_ phrase: Phrase) {
        Task {
            await ttsService.speak(phrase.phraseText)
            incrementUsage(phrase)
            logEvent(.phraseSpoken(phrase.phraseText, sessionId: sessionId))
        }
    }

    /// Speak custom text
    func speakCustomText() {
        guard !customText.isEmpty else { return }

        let text = customText
        customText = ""
        showKeyboard = false

        Task {
            await ttsService.speak(text)
            logEvent(.customTextSpoken(text, sessionId: sessionId))

            // Generate follow-up phrases if AI is enabled and online
            if reachability.isConnected {
                await generateFollowUpPhrases(for: text)
            }
        }
    }

    /// Stop current speech
    func stopSpeaking() {
        ttsService.stop()
    }

    // MARK: - Context Pack Generation

    /// Generate new context pack based on scenario
    func generateContextPack(scenario: String) async {
        guard reachability.isConnected else {
            error = "No network connection"
            HapticManager.shared.failure()
            return
        }

        isGeneratingPack = true
        error = nil

        do {
            let newPhrases = try await GeminiService.shared.generateContextPack(scenario: scenario)

            // Replace current phrases with generated ones
            await replacePhrasesWithGenerated(newPhrases)

            logEvent(UsageLog(
                eventType: UsageLog.EventType.contextPackGenerated.rawValue,
                eventData: scenario,
                sessionId: sessionId
            ))

            HapticManager.shared.success()
        } catch {
            self.error = "Failed to generate phrases"
            HapticManager.shared.failure()
        }

        isGeneratingPack = false
    }

    private func generateFollowUpPhrases(for text: String) async {
        isGeneratingPack = true

        do {
            let followUpPhrases = try await GeminiService.shared.generateFollowUpPhrases(spokenText: text)
            await replacePhrasesWithGenerated(followUpPhrases)
        } catch {
            print("Failed to generate follow-up phrases: \(error)")
        }

        isGeneratingPack = false
    }

    private func replacePhrasesWithGenerated(_ newPhraseTexts: [String]) async {
        guard let context = modelContext else { return }

        // Mark existing non-favorite phrases for deletion
        for phrase in phrases where !phrase.isFavorite {
            phrase.syncStatus = .pendingDelete
        }

        // Create new phrases
        for text in newPhraseTexts.prefix(8) {
            let phrase = Phrase(phraseText: text)
            context.insert(phrase)
        }

        do {
            try context.save()
            loadPhrases()
        } catch {
            print("Failed to save generated phrases: \(error)")
        }
    }

    // MARK: - Phrase Management

    /// Create a new phrase
    func createPhrase(_ text: String, category: String? = nil) {
        guard let context = modelContext else { return }

        let phrase = Phrase(phraseText: text, category: category)
        context.insert(phrase)

        do {
            try context.save()
            loadPhrases()
            HapticManager.shared.success()
        } catch {
            error = "Failed to create phrase"
            HapticManager.shared.failure()
        }
    }

    /// Delete a phrase
    func deletePhrase(_ phrase: Phrase) {
        guard let context = modelContext else { return }

        if phrase.serverID != nil {
            // Mark for server deletion
            phrase.syncStatus = .pendingDelete
        } else {
            // Delete locally only
            context.delete(phrase)
        }

        do {
            try context.save()
            loadPhrases()
        } catch {
            error = "Failed to delete phrase"
        }
    }

    /// Toggle favorite status
    func toggleFavorite(_ phrase: Phrase) {
        phrase.isFavorite.toggle()
        phrase.updatedAt = Date()

        if phrase.syncStatus == .synced {
            phrase.syncStatus = .pendingUpdate
        }

        do {
            try modelContext?.save()
            HapticManager.shared.tap()
        } catch {
            error = "Failed to update phrase"
        }
    }

    private func incrementUsage(_ phrase: Phrase) {
        phrase.usageCount += 1
        phrase.updatedAt = Date()

        if phrase.syncStatus == .synced {
            phrase.syncStatus = .pendingUpdate
        }

        try? modelContext?.save()
    }

    // MARK: - Analytics

    private func logEvent(_ log: UsageLog) {
        guard let context = modelContext else { return }
        context.insert(log)
        try? context.save()
    }

    // MARK: - Sync

    /// Trigger manual sync
    func sync() async {
        guard let context = modelContext else { return }
        await syncService.syncNow(context: context)
        loadPhrases()
    }
}

// MARK: - Settings View Model

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: UserSettings?
    @Published var isLoading: Bool = false
    @Published var error: String?

    var modelContext: ModelContext?
    private let syncService = SyncService.shared

    func loadSettings() {
        guard let context = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<UserSettings>()
            let results = try context.fetch(descriptor)

            if let existing = results.first {
                settings = existing
            } else {
                // Create default settings
                let newSettings = UserSettings()
                context.insert(newSettings)
                try context.save()
                settings = newSettings
            }
        } catch {
            self.error = "Failed to load settings"
        }
    }

    func updateLanguage(_ language: String) {
        settings?.language = language
        markPendingUpdate()
    }

    func updateVoiceSpeed(_ speed: Double) {
        settings?.voiceSpeed = speed
        markPendingUpdate()
    }

    func toggleAI(_ enabled: Bool) {
        settings?.aiEnabled = enabled
        markPendingUpdate()
    }

    func updateResponseMode(_ mode: String) {
        settings?.responseMode = mode
        markPendingUpdate()
    }

    private func markPendingUpdate() {
        settings?.updatedAt = Date()
        if settings?.syncStatus == .synced {
            settings?.syncStatus = .pendingUpdate
        }

        do {
            try modelContext?.save()
            HapticManager.shared.tap()
        } catch {
            error = "Failed to save settings"
        }
    }

    func sync() async {
        guard let context = modelContext else { return }
        await syncService.syncNow(context: context)
        loadSettings()
    }
}
