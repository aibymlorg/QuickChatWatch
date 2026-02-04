import SwiftUI

/// Login view for authentication
struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var isSignupMode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Logo/Title
                    VStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.cyan)

                        Text("QuickChat")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(isSignupMode ? "Create Account" : "Sign In")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)

                    // Email field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        TextField("email@example.com", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .font(.caption)
                    }

                    // Password field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        SecureField("Password", text: $viewModel.password)
                            .textContentType(isSignupMode ? .newPassword : .password)
                            .font(.caption)
                    }

                    // Error message
                    if let error = viewModel.error {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Submit button
                    Button {
                        Task {
                            if isSignupMode {
                                await viewModel.signup()
                            } else {
                                await viewModel.login()
                            }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isSignupMode ? "Sign Up" : "Sign In")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .disabled(viewModel.isLoading)

                    // Toggle signup/login
                    Button {
                        isSignupMode.toggle()
                    } label: {
                        Text(isSignupMode ? "Already have an account? Sign In" : "Need an account? Sign Up")
                            .font(.caption2)
                            .foregroundColor(.cyan)
                    }
                    .buttonStyle(.plain)

                    // Skip login (demo mode)
                    Button {
                        // Skip to main app without auth
                        viewModel.isAuthenticated = true
                    } label: {
                        Text("Continue without account")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
        }
    }
}

/// Compact login prompt for watch
struct CompactLoginPrompt: View {
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.largeTitle)
                .foregroundColor(.cyan)

            Text("Sign in to sync your phrases across devices")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            NavigationLink {
                LoginView()
            } label: {
                Text("Sign In")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)

            Button {
                viewModel.isAuthenticated = true
            } label: {
                Text("Skip")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

#Preview {
    LoginView()
}
