import SwiftUI
import SwiftData

/// Main phrase grid view - the primary interface for the watch app
struct PhraseGridView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PhraseGridViewModel()
    @ObservedObject private var ttsService = TTSService.shared
    @ObservedObject private var reachability = ReachabilityService.shared
    @ObservedObject private var phoneConnector = PhoneConnectorService.shared

    @State private var showSettings = false
    @State private var showVoiceInput = false
    @State private var showContextPhrases = true

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.cyan, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 6) {
                    // Header
                    headerView

                    // Context banner (from iPhone)
                    if let context = viewModel.currentContext {
                        contextBannerView(context)
                    }

                    // Status indicators
                    statusBar

                    // Phrase grid - show context phrases if available
                    if showContextPhrases && !viewModel.contextPhrases.isEmpty {
                        contextPhraseGrid
                    } else {
                        phraseGrid
                    }

                    // Bottom toolbar
                    bottomToolbar
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)

                // Keyboard overlay
                if viewModel.showKeyboard {
                    keyboardOverlay
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.modelContext = modelContext
                viewModel.loadPhrases()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showVoiceInput) {
                VoiceInputView(isPresented: $showVoiceInput) { command in
                    handleVoiceCommand(command)
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text("QuickChat")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            // iPhone connection indicator
            if phoneConnector.isPhoneReachable {
                Image(systemName: "iphone")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            }

            OfflineIndicator()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
    }

    private func contextBannerView(_ context: ReceivedContext) -> some View {
        Button {
            showContextPhrases.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "iphone")
                    .font(.system(size: 8))
                Image(systemName: context.icon)
                    .font(.system(size: 10))
                Text(context.displayName)
                    .font(.system(size: 10, weight: .medium))

                Spacer()

                Image(systemName: showContextPhrases ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.8))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var statusBar: some View {
        HStack {
            if viewModel.ttsStatus != .idle {
                TTSStatusIndicator(status: viewModel.ttsStatus)
            }

            if viewModel.isGeneratingPack {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("AI")
                        .font(.system(size: 10))
                }
                .foregroundColor(.white)
            }

            Spacer()

            // Toggle for context/saved phrases
            if !viewModel.contextPhrases.isEmpty {
                Button {
                    showContextPhrases.toggle()
                } label: {
                    Text(showContextPhrases ? "Saved" : "Context")
                        .font(.system(size: 8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 16)
    }

    private var contextPhraseGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(viewModel.contextPhrases.prefix(8), id: \.self) { phrase in
                    ContextPhraseButton(
                        text: phrase,
                        isPlaying: ttsService.currentText == phrase && ttsService.status == .playing,
                        onTap: {
                            viewModel.speakContextPhrase(phrase)
                        }
                    )
                    .frame(height: 50)
                }
            }
        }
    }

    private var phraseGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(viewModel.phrases.prefix(8)) { phrase in
                    PhraseButtonView(
                        phrase: phrase,
                        isPlaying: ttsService.currentText == phrase.phraseText && ttsService.status == .playing,
                        onTap: {
                            viewModel.speak(phrase)
                        }
                    )
                    .frame(height: 50)
                }
            }
        }
    }

    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            // Voice button
            Button {
                showVoiceInput = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14))
                    Text("Voice")
                        .font(.system(size: 9))
                }
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            // Type button
            Button {
                viewModel.showKeyboard = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 14))
                    Text("Type")
                        .font(.system(size: 9))
                }
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            Spacer()

            // Stop button (when playing)
            if viewModel.ttsStatus == .playing || viewModel.ttsStatus == .loading {
                Button {
                    viewModel.stopSpeaking()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14))
                        Text("Stop")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
    }

    private var keyboardOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.showKeyboard = false
                }

            CompactTypeMessageView(
                text: $viewModel.customText,
                onSpeak: {
                    viewModel.speakCustomText()
                },
                onClose: {
                    viewModel.showKeyboard = false
                }
            )
            .padding()
        }
    }

    // MARK: - Voice Command Handling

    private func handleVoiceCommand(_ command: VoiceCommand) {
        switch command {
        case .speak(let text):
            Task {
                await ttsService.speak(text)
            }

        case .loadContextPack(let scenario):
            Task {
                await viewModel.generateContextPack(scenario: scenario)
            }

        case .openSettings:
            showSettings = true

        case .sync:
            Task {
                await viewModel.sync()
            }

        case .stop:
            viewModel.stopSpeaking()

        case .emergency:
            // Activate emergency mode
            NotificationCenter.default.post(name: .emergencyActivated, object: nil)
        }
    }
}

// MARK: - Context Phrase Button

struct ContextPhraseButton: View {
    let text: String
    let isPlaying: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isPlaying ? .purple : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(4)
                .background(isPlaying ? Color.purple.opacity(0.3) : Color.white.opacity(0.95))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PhraseGridView()
        .modelContainer(for: [Phrase.self, UserSettings.self, UsageLog.self], inMemory: true)
}
