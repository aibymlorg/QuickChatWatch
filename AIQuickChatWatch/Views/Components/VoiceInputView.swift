import SwiftUI

/// View for voice command input
struct VoiceInputView: View {
    @ObservedObject var voiceService = VoiceInputService.shared
    @Binding var isPresented: Bool

    let onCommand: (VoiceCommand) -> Void

    @State private var mode: InputMode = .command

    enum InputMode {
        case command
        case dictation
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text(mode == .command ? "Voice Command" : "Dictation")
                    .font(.headline)
                Spacer()
                Button {
                    voiceService.stopListening()
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Status indicator
            if voiceService.isListening {
                listeningIndicator
            } else {
                startPrompt
            }

            // Transcribed text
            if !voiceService.transcribedText.isEmpty {
                Text(voiceService.transcribedText)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }

            // Error
            if let error = voiceService.error {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
            }

            // Mode toggle
            Picker("Mode", selection: $mode) {
                Text("Command").tag(InputMode.command)
                Text("Dictate").tag(InputMode.dictation)
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in
                voiceService.stopListening()
            }
        }
        .padding()
        .onAppear {
            setupCallbacks()
            startListening()
        }
        .onDisappear {
            voiceService.stopListening()
        }
    }

    private var listeningIndicator: some View {
        VStack(spacing: 8) {
            // Animated mic icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(Color.red.opacity(0.4))
                    .frame(width: 60, height: 60)

                Image(systemName: "mic.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.red)
            }

            Text("Listening...")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                voiceService.stopListening()
            } label: {
                Text("Stop")
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }

    private var startPrompt: some View {
        VStack(spacing: 8) {
            Button {
                startListening()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 70, height: 70)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)

            Text(mode == .command ? "Tap to speak a command" : "Tap to dictate")
                .font(.caption)
                .foregroundColor(.secondary)

            if mode == .command {
                Text("Try: \"Say thank you\" or \"Load hospital\"")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func setupCallbacks() {
        voiceService.onVoiceCommand = { command in
            onCommand(command)
            isPresented = false
        }

        voiceService.onDictationComplete = { text in
            onCommand(.speak(text))
            isPresented = false
        }
    }

    private func startListening() {
        Task {
            if mode == .command {
                await voiceService.startVoiceCommands()
            } else {
                await voiceService.startDictation()
            }
        }
    }
}

/// Compact voice input button for the main grid
struct VoiceInputButton: View {
    @State private var showVoiceInput = false
    let onCommand: (VoiceCommand) -> Void

    var body: some View {
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
        .sheet(isPresented: $showVoiceInput) {
            VoiceInputView(isPresented: $showVoiceInput, onCommand: onCommand)
        }
    }
}

/// Floating voice button overlay
struct FloatingVoiceButton: View {
    @ObservedObject var voiceService = VoiceInputService.shared
    @State private var isExpanded = false

    let onCommand: (VoiceCommand) -> Void

    var body: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button {
                    if voiceService.isListening {
                        voiceService.stopListening()
                    } else {
                        isExpanded = true
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(voiceService.isListening ? Color.red : Color.cyan)
                            .frame(width: 50, height: 50)
                            .shadow(radius: 4)

                        Image(systemName: voiceService.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 8)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $isExpanded) {
            VoiceInputView(isPresented: $isExpanded, onCommand: onCommand)
        }
    }
}

#Preview {
    VoiceInputView(isPresented: .constant(true)) { command in
        print("Command: \(command)")
    }
}
