import SwiftUI
import SwiftData

/// Main phrase grid view - the primary interface for the watch app
struct PhraseGridView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PhraseGridViewModel()
    @ObservedObject private var ttsService = TTSService.shared
    @ObservedObject private var reachability = ReachabilityService.shared

    @State private var showSettings = false
    @State private var showVoiceInput = false

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

                VStack(spacing: 8) {
                    // Header
                    headerView

                    // Status indicators
                    statusBar

                    // Phrase grid
                    phraseGrid

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
        }
        .frame(height: 16)
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

#Preview {
    PhraseGridView()
        .modelContainer(for: [Phrase.self, UserSettings.self, UsageLog.self], inMemory: true)
}
