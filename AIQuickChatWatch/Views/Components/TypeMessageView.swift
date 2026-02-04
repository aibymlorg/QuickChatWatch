import SwiftUI

/// View for typing custom messages with dictation support
struct TypeMessageView: View {
    @Binding var text: String
    @Binding var isPresented: Bool
    let onSpeak: () -> Void

    @State private var showDictation = false

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
                    showDictation = true
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
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
    }

    private let quickPhrases = [
        "Help",
        "Yes",
        "No",
        "Thank you",
        "Please wait"
    ]
}

/// Compact version for watch
struct CompactTypeMessageView: View {
    @Binding var text: String
    let onSpeak: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Type")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            TextField("Message", text: $text)
                .font(.caption)

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
    }
}

#Preview {
    TypeMessageView(
        text: .constant("Hello"),
        isPresented: .constant(true),
        onSpeak: {}
    )
}
