import Foundation
import AVFoundation
import Combine

/// Text-to-Speech status enum matching web app
enum TTSStatus: String {
    case idle = "IDLE"
    case loading = "LOADING"
    case playing = "PLAYING"
    case error = "ERROR"
}

/// Service for text-to-speech with Gemini primary and AVSpeechSynthesizer fallback
@MainActor
final class TTSService: NSObject, ObservableObject {
    static let shared = TTSService()

    @Published private(set) var status: TTSStatus = .idle
    @Published private(set) var currentText: String?

    private var audioPlayer: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var speechDelegate: SpeechDelegate?

    private let reachability = ReachabilityService.shared

    override private init() {
        super.init()
        setupAudioSession()
        speechDelegate = SpeechDelegate { [weak self] in
            self?.handleSpeechFinished()
        }
        speechSynthesizer.delegate = speechDelegate
    }

    // MARK: - Public API

    /// Speak the given text using best available TTS
    /// - Parameter text: Text to speak
    func speak(_ text: String) async {
        guard status != .loading && status != .playing else { return }

        status = .loading
        currentText = text
        HapticManager.shared.startSpeaking()

        // Try Gemini TTS if online
        if reachability.isConnected {
            do {
                let audioData = try await GeminiService.shared.generateSpeech(text: text)
                try playAudio(audioData)
                return
            } catch {
                print("Gemini TTS failed, falling back to AVSpeech: \(error)")
            }
        }

        // Fallback to AVSpeechSynthesizer
        speakWithAVSpeech(text)
    }

    /// Stop any current speech
    func stop() {
        audioPlayer?.stop()
        speechSynthesizer.stopSpeaking(at: .immediate)
        status = .idle
        currentText = nil
    }

    // MARK: - Private Methods

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    private func playAudio(_ data: Data) throws {
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()

        status = .playing

        if audioPlayer?.play() != true {
            throw TTSError.playbackFailed
        }
    }

    private func speakWithAVSpeech(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9 // Slightly slower for clarity
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        // Try to use a natural voice
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }

        status = .playing
        speechSynthesizer.speak(utterance)
    }

    private func handleSpeechFinished() {
        status = .idle
        currentText = nil
        HapticManager.shared.doneSpeaking()
    }
}

// MARK: - AVAudioPlayerDelegate

extension TTSService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            handleSpeechFinished()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            status = .error
            HapticManager.shared.failure()

            // Try fallback if Gemini audio failed
            if let text = currentText {
                speakWithAVSpeech(text)
            }
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate Helper

private class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish()
    }
}

// MARK: - Errors

enum TTSError: Error, LocalizedError {
    case playbackFailed
    case audioSessionFailed

    var errorDescription: String? {
        switch self {
        case .playbackFailed:
            return "Failed to play audio"
        case .audioSessionFailed:
            return "Failed to configure audio session"
        }
    }
}
