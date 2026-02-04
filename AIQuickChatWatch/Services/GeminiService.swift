import Foundation

/// Service for interacting with Gemini API for context pack generation and TTS
actor GeminiService {
    static let shared = GeminiService()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private var apiKey: String? {
        get async {
            // Try to get from keychain first, then environment
            if let key = await KeychainService.shared.getGeminiAPIKey() {
                return key
            }
            return ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
        }
    }

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let textModel = "gemini-2.5-flash"
    private let ttsModel = "gemini-2.5-flash-preview-tts"

    /// Default voice for TTS - Fenrir is a deep, calm voice suitable for assistive devices
    private let defaultVoice = "Fenrir"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Context Pack Generation

    /// Generate context-aware phrases for a given scenario
    /// - Parameter scenario: Description of the current context/environment
    /// - Returns: Array of relevant phrases (6-8 phrases)
    func generateContextPack(scenario: String) async throws -> [String] {
        guard let key = await apiKey else {
            throw GeminiError.missingAPIKey
        }

        let prompt = """
        Generate 6 short, useful, spoken phrases (max 5 words each) for a person with speech difficulties in this specific scenario: "\(scenario)".
        """

        let request = GeminiRequest(
            contents: [
                GeminiRequest.GeminiContent(
                    parts: [GeminiRequest.GeminiPart(text: prompt)]
                )
            ],
            generationConfig: GeminiRequest.GenerationConfig(
                responseMimeType: "application/json",
                responseSchema: GeminiRequest.ResponseSchema(
                    type: "array",
                    items: GeminiRequest.SchemaItems(type: "string")
                )
            )
        )

        let url = URL(string: "\(baseURL)/models/\(textModel):generateContent?key=\(key)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GeminiError.requestFailed
        }

        let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)

        guard let text = geminiResponse.candidates?.first?.content?.parts?.first?.text,
              let phrases = try? JSONDecoder().decode([String].self, from: text.data(using: .utf8) ?? Data()) else {
            // Return default phrases if parsing fails
            return defaultPhrases
        }

        return phrases
    }

    /// Generate follow-up phrases based on what was just spoken
    /// - Parameter spokenText: The text that was just spoken
    /// - Returns: Array of relevant follow-up phrases
    func generateFollowUpPhrases(spokenText: String) async throws -> [String] {
        let scenario = "User just said: \"\(spokenText)\". Generate 6-8 relevant follow-up dialogue choices for continuing this conversation."
        return try await generateContextPack(scenario: scenario)
    }

    // MARK: - Text-to-Speech

    /// Generate speech audio from text using Gemini TTS
    /// - Parameters:
    ///   - text: Text to convert to speech
    ///   - voiceName: Voice to use (default: Fenrir)
    /// - Returns: WAV audio data ready for playback
    func generateSpeech(text: String, voiceName: String? = nil) async throws -> Data {
        guard let key = await apiKey else {
            throw GeminiError.missingAPIKey
        }

        let voice = voiceName ?? defaultVoice

        let request = GeminiTTSRequest(
            contents: [
                GeminiTTSRequest.Content(
                    parts: [GeminiTTSRequest.Part(text: text)]
                )
            ],
            generationConfig: GeminiTTSRequest.GenerationConfig(
                responseModalities: ["AUDIO"],
                speechConfig: GeminiTTSRequest.SpeechConfig(
                    voiceConfig: GeminiTTSRequest.VoiceConfig(
                        prebuiltVoiceConfig: GeminiTTSRequest.PrebuiltVoiceConfig(
                            voiceName: voice
                        )
                    )
                )
            )
        )

        let url = URL(string: "\(baseURL)/models/\(ttsModel):generateContent?key=\(key)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GeminiError.requestFailed
        }

        let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)

        guard let base64Audio = geminiResponse.candidates?.first?.content?.parts?.first?.inlineData?.data else {
            throw GeminiError.noAudioData
        }

        // Convert base64 PCM to WAV format
        guard let wavData = AudioConverter.base64PCMToWAV(base64Audio) else {
            throw GeminiError.audioConversionFailed
        }

        return wavData
    }

    // MARK: - Helpers

    /// Default phrases for offline use or when API fails
    var defaultPhrases: [String] {
        ["Hello", "Yes", "No", "Help", "Thanks", "Goodbye"]
    }

    /// Available TTS voice options
    static let availableVoices = [
        "Fenrir",   // Deep, calm
        "Aoede",    // Female, warm
        "Charon",   // Male, authoritative
        "Kore",     // Female, gentle
        "Puck"      // Neutral, friendly
    ]
}

// MARK: - Errors

enum GeminiError: Error, LocalizedError {
    case missingAPIKey
    case requestFailed
    case noAudioData
    case audioConversionFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key not configured"
        case .requestFailed:
            return "Failed to communicate with Gemini API"
        case .noAudioData:
            return "No audio data received from TTS"
        case .audioConversionFailed:
            return "Failed to convert audio format"
        case .invalidResponse:
            return "Invalid response from Gemini API"
        }
    }
}
