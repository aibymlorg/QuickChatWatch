import SwiftUI
import SwiftData

/// Root content view that handles authentication routing
struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            // Always show the phrase grid - auth is optional
            PhraseGridView()
        }
        .environmentObject(authViewModel)
    }
}

/// Alternative content view with mandatory auth
struct AuthenticatedContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                PhraseGridView()
            } else {
                LoginView()
            }
        }
        .environmentObject(authViewModel)
    }
}

/// Splash screen for initial loading
struct SplashView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundColor(.cyan)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )

            Text("QuickChat")
                .font(.title2)
                .fontWeight(.bold)

            Text("AI-Powered AAC")
                .font(.caption)
                .foregroundColor(.secondary)

            ProgressView()
                .padding(.top)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Phrase.self, UserSettings.self, UsageLog.self], inMemory: true)
}
