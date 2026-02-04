import Foundation

// MARK: - Authentication

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct SignupRequest: Codable {
    let email: String
    let password: String
    let fullName: String?
    let companyName: String?
    let phone: String?
    let organizationType: String?
    let marketingConsent: Bool?
}

struct AuthResponse: Codable {
    let token: String
    let user: UserDTO
}

struct UserDTO: Codable {
    let id: String
    let email: String
    let fullName: String?
    let companyName: String?
    let phone: String?
    let accountStatus: String
    let subscriptionTier: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email, phone
        case fullName = "full_name"
        case companyName = "company_name"
        case accountStatus = "account_status"
        case subscriptionTier = "subscription_tier"
        case createdAt = "created_at"
    }
}

// MARK: - Phrases

struct PhraseDTO: Codable {
    let id: String
    let phraseText: String
    let category: String?
    let usageCount: Int
    let isFavorite: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case phraseText = "phrase_text"
        case category
        case usageCount = "usage_count"
        case isFavorite = "is_favorite"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct PhrasesResponse: Codable {
    let phrases: [PhraseDTO]
}

struct CreatePhraseRequest: Codable {
    let phraseText: String
    let category: String?
}

struct UpdatePhraseRequest: Codable {
    let phraseText: String?
    let category: String?
    let usageCount: Int?
    let isFavorite: Bool?
}

struct CreatePhraseResponse: Codable {
    let phrase: PhraseDTO
}

// MARK: - Settings

struct SettingsDTO: Codable {
    let language: String?
    let voiceSpeed: Double?
    let aiEnabled: Bool?
    let responseMode: String?
}

struct SettingsResponse: Codable {
    let settings: SettingsDTO
}

struct UpdateSettingsRequest: Codable {
    let settings: SettingsDTO
}

// MARK: - Analytics

struct LogEventRequest: Codable {
    let eventType: String
    let eventData: String?
    let phraseUsed: String?
    let sessionId: String?
}

struct LogEventResponse: Codable {
    let success: Bool
}

// MARK: - Gemini API

struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GenerationConfig?

    struct GeminiContent: Codable {
        let parts: [GeminiPart]
    }

    struct GeminiPart: Codable {
        let text: String
    }

    struct GenerationConfig: Codable {
        let responseMimeType: String?
        let responseSchema: ResponseSchema?
    }

    struct ResponseSchema: Codable {
        let type: String
        let items: SchemaItems?
    }

    struct SchemaItems: Codable {
        let type: String
    }
}

struct GeminiResponse: Codable {
    let candidates: [Candidate]?

    struct Candidate: Codable {
        let content: Content?
    }

    struct Content: Codable {
        let parts: [Part]?
    }

    struct Part: Codable {
        let text: String?
        let inlineData: InlineData?
    }

    struct InlineData: Codable {
        let mimeType: String?
        let data: String?
    }
}

struct GeminiTTSRequest: Codable {
    let contents: [Content]
    let generationConfig: GenerationConfig

    struct Content: Codable {
        let parts: [Part]
    }

    struct Part: Codable {
        let text: String
    }

    struct GenerationConfig: Codable {
        let responseModalities: [String]
        let speechConfig: SpeechConfig
    }

    struct SpeechConfig: Codable {
        let voiceConfig: VoiceConfig
    }

    struct VoiceConfig: Codable {
        let prebuiltVoiceConfig: PrebuiltVoiceConfig
    }

    struct PrebuiltVoiceConfig: Codable {
        let voiceName: String
    }
}

// MARK: - Error Response

struct APIError: Codable, Error {
    let error: String
    let message: String?
}
