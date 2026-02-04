import Foundation

/// Actor-based HTTP client for API communication with JWT authentication
actor APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        // Use environment variable or default to production URL
        let urlString = ProcessInfo.processInfo.environment["API_URL"] ?? "https://api.aiquickchat.com"
        self.baseURL = URL(string: urlString)!

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Authentication

    func login(email: String, password: String) async throws -> AuthResponse {
        let request = LoginRequest(email: email, password: password)
        let response: AuthResponse = try await post("/api/auth/login", body: request, authenticated: false)

        // Save token to keychain
        try await KeychainService.shared.saveAuthToken(response.token)
        try await KeychainService.shared.saveUserEmail(email)

        return response
    }

    func signup(request: SignupRequest) async throws -> AuthResponse {
        let response: AuthResponse = try await post("/api/auth/signup", body: request, authenticated: false)

        // Save token to keychain
        try await KeychainService.shared.saveAuthToken(response.token)
        try await KeychainService.shared.saveUserEmail(request.email)

        return response
    }

    func logout() async throws {
        try await KeychainService.shared.clearAll()
    }

    func getProfile() async throws -> UserDTO {
        try await get("/api/auth/profile")
    }

    // MARK: - Phrases

    func getPhrases(category: String? = nil) async throws -> [PhraseDTO] {
        var endpoint = "/api/phrases"
        if let category = category {
            endpoint += "?category=\(category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category)"
        }
        let response: PhrasesResponse = try await get(endpoint)
        return response.phrases
    }

    func createPhrase(phraseText: String, category: String? = nil) async throws -> PhraseDTO {
        let request = CreatePhraseRequest(phraseText: phraseText, category: category)
        let response: CreatePhraseResponse = try await post("/api/phrases", body: request)
        return response.phrase
    }

    func updatePhrase(id: String, updates: UpdatePhraseRequest) async throws -> PhraseDTO {
        try await put("/api/phrases/\(id)", body: updates)
    }

    func deletePhrase(id: String) async throws {
        try await delete("/api/phrases/\(id)")
    }

    func incrementPhraseUsage(id: String) async throws {
        let _: EmptyResponse = try await post("/api/phrases/\(id)/increment-usage", body: EmptyBody())
    }

    // MARK: - Settings

    func getSettings() async throws -> SettingsDTO {
        let response: SettingsResponse = try await get("/api/settings")
        return response.settings
    }

    func updateSettings(_ settings: SettingsDTO) async throws -> SettingsDTO {
        let request = UpdateSettingsRequest(settings: settings)
        let response: SettingsResponse = try await put("/api/settings", body: request)
        return response.settings
    }

    // MARK: - Analytics

    func logEvent(_ event: LogEventRequest) async throws {
        let _: LogEventResponse = try await post("/api/analytics/log", body: event)
    }

    func logEvents(_ events: [LogEventRequest]) async throws {
        // Batch log events - fire and forget for efficiency
        for event in events {
            try await logEvent(event)
        }
    }

    // MARK: - Push Notifications & Instructions

    /// Register device token for push notifications
    func registerDeviceToken(_ token: String) async throws {
        let request = RegisterDeviceRequest(
            token: token,
            platform: "watchos",
            deviceModel: getDeviceModel()
        )
        let _: EmptyResponse = try await post("/api/devices/register", body: request)
    }

    /// Unregister device token
    func unregisterDeviceToken(_ token: String) async throws {
        try await delete("/api/devices/\(token)")
    }

    /// Get pending instructions from server
    func getPendingInstructions() async throws -> [ServerInstruction] {
        let response: PendingInstructionsResponse = try await get("/api/instructions/pending")
        return response.instructions
    }

    /// Mark an instruction as processed
    func markInstructionProcessed(_ instructionId: String) async throws {
        let _: EmptyResponse = try await post(
            "/api/instructions/\(instructionId)/processed",
            body: EmptyBody()
        )
    }

    /// Send instruction to another device (caregiver -> patient)
    func sendInstruction(_ instruction: SendInstructionRequest) async throws {
        let _: EmptyResponse = try await post("/api/instructions/send", body: instruction)
    }

    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        return modelCode ?? "Apple Watch"
    }

    // MARK: - Private HTTP Methods

    private func get<T: Decodable>(_ endpoint: String, authenticated: Bool = true) async throws -> T {
        let request = try await buildRequest(endpoint: endpoint, method: "GET", authenticated: authenticated)
        return try await execute(request)
    }

    private func post<T: Decodable, B: Encodable>(
        _ endpoint: String,
        body: B,
        authenticated: Bool = true
    ) async throws -> T {
        var request = try await buildRequest(endpoint: endpoint, method: "POST", authenticated: authenticated)
        request.httpBody = try encoder.encode(body)
        return try await execute(request)
    }

    private func put<T: Decodable, B: Encodable>(
        _ endpoint: String,
        body: B,
        authenticated: Bool = true
    ) async throws -> T {
        var request = try await buildRequest(endpoint: endpoint, method: "PUT", authenticated: authenticated)
        request.httpBody = try encoder.encode(body)
        return try await execute(request)
    }

    private func delete(_ endpoint: String, authenticated: Bool = true) async throws {
        let request = try await buildRequest(endpoint: endpoint, method: "DELETE", authenticated: authenticated)
        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIClientError.httpError(httpResponse.statusCode)
        }
    }

    private func buildRequest(
        endpoint: String,
        method: String,
        authenticated: Bool
    ) async throws -> URLRequest {
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            throw APIClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated {
            guard let token = await KeychainService.shared.getAuthToken() else {
                throw APIClientError.notAuthenticated
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to decode error response
            if let apiError = try? decoder.decode(APIError.self, from: data) {
                throw APIClientError.serverError(apiError.error)
            }
            throw APIClientError.httpError(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIClientError.decodingFailed(error)
        }
    }
}

// MARK: - Helper Types

private struct EmptyBody: Encodable {}

private struct EmptyResponse: Decodable {}

// MARK: - Errors

enum APIClientError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case notAuthenticated
    case httpError(Int)
    case serverError(String)
    case decodingFailed(Error)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .notAuthenticated:
            return "Please log in to continue"
        case .httpError(let code):
            return "Server error: \(code)"
        case .serverError(let message):
            return message
        case .decodingFailed(let error):
            return "Failed to process response: \(error.localizedDescription)"
        case .networkUnavailable:
            return "No network connection"
        }
    }
}
