import SwiftUI

/// View for typing custom messages with dictation support
struct TypeMessageView: View {
    @Binding var text: String
    @Binding var isPresented: Bool
    let onSpeak: () -> Void

    @ObservedObject private var voiceService = VoiceInputService.shared
    @State private var isDictating = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Type Message")
                    .font(.headline)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Text field with dictation
            TextField("What do you want to say?", text: $text)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)

            // Action buttons
            HStack(spacing: 12) {
                // Dictation button
                Button {
                    startDictation()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isDictating ? Color.red : Color.blue.opacity(0.2))
                            .frame(width: 44, height: 44)

                        if isDictating {
                            Image(systemName: "stop.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Speak button
                Button {
                    if !text.isEmpty {
                        onSpeak()
                    }
                } label: {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                        Text("Speak")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(text.isEmpty ? Color.gray : Color.cyan)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty)
            }

            // Dictation status
            if isDictating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Listening...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Quick phrases
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick phrases")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickPhrases, id: \.self) { phrase in
                            Button {
                                text = phrase
                            } label: {
                                Text(phrase)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            setupDictationCallback()
        }
        .onDisappear {
            voiceService.stopListening()
        }
    }

    private let quickPhrases = [
        "Help",
        "Yes",
        "No",
        "Thank you",
        "Please wait"
    ]

    private func setupDictationCallback() {
        voiceService.onDictationComplete = { dictatedText in
            text = dictatedText
            isDictating = false
        }
    }

    private func startDictation() {
        if isDictating {
            voiceService.stopListening()
            isDictating = false
        } else {
            isDictating = true
            Task {
                await voiceService.startDictation()
            }
        }
    }
}

/// Compact version for watch
struct CompactTypeMessageView: View {
    @Binding var text: String
    let onSpeak: () -> Void
    let onClose: () -> Void

    @ObservedObject private var voiceService = VoiceInputService.shared
    @State private var isDictating = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Type")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()

                // Dictation button
                Button {
                    toggleDictation()
                } label: {
                    Image(systemName: isDictating ? "stop.fill" : "mic.fill")
                        .font(.caption)
                        .foregroundColor(isDictating ? .red : .blue)
                }
                .buttonStyle(.plain)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            if isDictating {
                // Dictation mode
                VStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundColor(.red)

                    Text(voiceService.transcribedText.isEmpty ? "Listening..." : voiceService.transcribedText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .frame(height: 50)
            } else {
                TextField("Message", text: $text)
                    .font(.caption)
            }

            Button {
                if !text.isEmpty {
                    onSpeak()
                }
            } label: {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                    Text("Speak")
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(text.isEmpty ? Color.gray : Color.cyan)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty)
        }
        .padding(8)
        .background(Color.black.opacity(0.9))
        .cornerRadius(12)
        .onAppear {
            setupCallback()
        }
        .onDisappear {
            voiceService.stopListening()
        }
    }

    private func setupCallback() {
        voiceService.onDictationComplete = { dictatedText in
            text = dictatedText
            isDictating = false
        }
    }

    private func toggleDictation() {
        if isDictating {
            voiceService.stopListening()
            // Use whatever was transcribed
            if !voiceService.transcribedText.isEmpty {
                text = voiceService.transcribedText
            }
            isDictating = false
        } else {
            isDictating = true
            Task {
                await voiceService.startDictation()
            }
        }
    }
}

#Preview {
    TypeMessageView(
        text: .constant("Hello"),
        isPresented: .constant(true),
        onSpeak: {}
    )
}
