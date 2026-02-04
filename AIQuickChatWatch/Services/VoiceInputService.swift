import Foundation
import Speech
import AVFoundation
import Combine

/// Service for handling voice input via dictation and voice commands
@MainActor
final class VoiceInputService: NSObject, ObservableObject {
    static let shared = VoiceInputService()

    @Published private(set) var isListening: Bool = false
    @Published private(set) var transcribedText: String = ""
    @Published private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published private(set) var error: String?

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    /// Callback for voice commands
    var onVoiceCommand: ((VoiceCommand) -> Void)?

    /// Callback when dictation completes
    var onDictationComplete: ((String) -> Void)?

    private override init() {
        // Initialize with user's preferred language
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()

        speechRecognizer?.delegate = self
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    // MARK: - Dictation

    /// Start listening for dictation
    func startDictation() async {
        guard !isListening else { return }

        // Check authorization
        guard authorizationStatus == .authorized else {
            let authorized = await requestAuthorization()
            if !authorized {
                error = "Speech recognition not authorized"
                return
            }
        }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            error = "Speech recognition not available"
            return
        }

        do {
            try await startRecognition(mode: .dictation)
        } catch {
            self.error = "Failed to start: \(error.localizedDescription)"
        }
    }

    /// Start listening for voice commands
    func startVoiceCommands() async {
        guard !isListening else { return }

        guard authorizationStatus == .authorized else {
            let authorized = await requestAuthorization()
            if !authorized {
                error = "Speech recognition not authorized"
                return
            }
        }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            error = "Speech recognition not available"
            return
        }

        do {
            try await startRecognition(mode: .voiceCommand)
        } catch {
            self.error = "Failed to start: \(error.localizedDescription)"
        }
    }

    /// Stop listening
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    // MARK: - Private

    private enum RecognitionMode {
        case dictation
        case voiceCommand
    }

    private func startRecognition(mode: RecognitionMode) async throws {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceInputError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
        transcribedText = ""
        error = nil

        HapticManager.shared.startSpeaking()

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString

                    if result.isFinal {
                        self.handleFinalResult(result.bestTranscription.formattedString, mode: mode)
                    }
                }

                if let error = error {
                    self.error = error.localizedDescription
                    self.stopListening()
                }
            }
        }

        // Auto-stop after 10 seconds for voice commands, 30 for dictation
        let timeout: TimeInterval = mode == .voiceCommand ? 10 : 30
        Task {
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if self.isListening {
                self.stopListening()
                if mode == .dictation && !self.transcribedText.isEmpty {
                    self.onDictationComplete?(self.transcribedText)
                }
            }
        }
    }

    private func handleFinalResult(_ text: String, mode: RecognitionMode) {
        stopListening()
        HapticManager.shared.success()

        switch mode {
        case .dictation:
            onDictationComplete?(text)

        case .voiceCommand:
            if let command = parseVoiceCommand(text) {
                onVoiceCommand?(command)
            }
        }
    }

    // MARK: - Voice Command Parsing

    private func parseVoiceCommand(_ text: String) -> VoiceCommand? {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Emergency commands (highest priority)
        if lowercased.contains("emergency") || lowercased.contains("help me") || lowercased.contains("911") {
            return .emergency
        }

        // Speak commands
        if lowercased.hasPrefix("say ") || lowercased.hasPrefix("speak ") {
            let phrase = String(lowercased.dropFirst(lowercased.hasPrefix("say ") ? 4 : 6))
            return .speak(phrase)
        }

        // Load context pack
        if lowercased.hasPrefix("load ") {
            let scenario = String(lowercased.dropFirst(5))
                .replacingOccurrences(of: " phrases", with: "")
                .replacingOccurrences(of: " pack", with: "")
            return .loadContextPack(scenario)
        }

        // Settings commands
        if lowercased.contains("settings") || lowercased.contains("preferences") {
            return .openSettings
        }

        // Sync command
        if lowercased.contains("sync") || lowercased.contains("refresh") {
            return .sync
        }

        // Stop speaking
        if lowercased.contains("stop") || lowercased.contains("quiet") || lowercased.contains("silence") {
            return .stop
        }

        // Quick phrases
        if lowercased == "yes" || lowercased == "yeah" {
            return .speak("Yes")
        }
        if lowercased == "no" || lowercased == "nope" {
            return .speak("No")
        }
        if lowercased.contains("thank") {
            return .speak("Thank you")
        }
        if lowercased.contains("water") {
            return .speak("I need water")
        }
        if lowercased.contains("bathroom") || lowercased.contains("restroom") || lowercased.contains("toilet") {
            return .speak("I need to use the bathroom")
        }
        if lowercased.contains("pain") || lowercased.contains("hurt") {
            return .speak("I'm in pain")
        }
        if lowercased.contains("nurse") || lowercased.contains("doctor") {
            return .speak("Please call the nurse")
        }

        // If nothing matched, treat as a phrase to speak
        if !lowercased.isEmpty && lowercased.count > 2 {
            return .speak(text)
        }

        return nil
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension VoiceInputService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                self.error = "Speech recognition unavailable"
                self.stopListening()
            }
        }
    }
}

// MARK: - Voice Commands

enum VoiceCommand {
    case speak(String)
    case loadContextPack(String)
    case openSettings
    case sync
    case stop
    case emergency

    var description: String {
        switch self {
        case .speak(let text): return "Speak: \(text)"
        case .loadContextPack(let scenario): return "Load: \(scenario)"
        case .openSettings: return "Open Settings"
        case .sync: return "Sync Data"
        case .stop: return "Stop Speaking"
        case .emergency: return "Emergency"
        }
    }
}

// MARK: - Errors

enum VoiceInputError: Error, LocalizedError {
    case notAuthorized
    case notAvailable
    case requestCreationFailed
    case audioSessionFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Speech recognition not authorized"
        case .notAvailable: return "Speech recognition not available"
        case .requestCreationFailed: return "Failed to create recognition request"
        case .audioSessionFailed: return "Failed to configure audio"
        }
    }
}
