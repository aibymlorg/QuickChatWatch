import Foundation
import SwiftData
import Combine

/// View model for authentication state management
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var user: UserDTO?

    @Published var email: String = ""
    @Published var password: String = ""

    private var cancellables = Set<AnyCancellable>()

    init() {
        checkAuthState()
    }

    /// Check if user is already authenticated
    func checkAuthState() {
        Task {
            if let token = await KeychainService.shared.getAuthToken(), !token.isEmpty {
                // Verify token is still valid by fetching profile
                do {
                    let profile = try await APIClient.shared.getProfile()
                    self.user = profile
                    self.isAuthenticated = true
                } catch {
                    // Token is invalid, clear it
                    try? await KeychainService.shared.clearAll()
                    self.isAuthenticated = false
                }
            } else {
                self.isAuthenticated = false
            }
        }
    }

    /// Log in with email and password
    func login() async {
        guard !email.isEmpty && !password.isEmpty else {
            error = "Please enter email and password"
            return
        }

        isLoading = true
        error = nil

        do {
            let response = try await APIClient.shared.login(email: email, password: password)
            user = response.user
            isAuthenticated = true
            clearForm()
            HapticManager.shared.success()
        } catch let apiError as APIClientError {
            error = apiError.localizedDescription
            HapticManager.shared.failure()
        } catch {
            self.error = "Login failed. Please try again."
            HapticManager.shared.failure()
        }

        isLoading = false
    }

    /// Sign up with email and password
    func signup() async {
        guard !email.isEmpty && !password.isEmpty else {
            error = "Please enter email and password"
            return
        }

        guard password.count >= 6 else {
            error = "Password must be at least 6 characters"
            return
        }

        isLoading = true
        error = nil

        do {
            let request = SignupRequest(
                email: email,
                password: password,
                fullName: nil,
                companyName: nil,
                phone: nil,
                organizationType: nil,
                marketingConsent: false
            )
            let response = try await APIClient.shared.signup(request: request)
            user = response.user
            isAuthenticated = true
            clearForm()
            HapticManager.shared.success()
        } catch let apiError as APIClientError {
            error = apiError.localizedDescription
            HapticManager.shared.failure()
        } catch {
            self.error = "Signup failed. Please try again."
            HapticManager.shared.failure()
        }

        isLoading = false
    }

    /// Log out
    func logout() async {
        isLoading = true

        do {
            try await APIClient.shared.logout()
        } catch {
            print("Logout error: \(error)")
        }

        user = nil
        isAuthenticated = false
        clearForm()
        isLoading = false
        HapticManager.shared.success()
    }

    private func clearForm() {
        email = ""
        password = ""
        error = nil
    }
}
