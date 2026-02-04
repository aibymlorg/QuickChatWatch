import SwiftUI

/// Individual phrase button for the grid
struct PhraseButtonView: View {
    let phrase: Phrase
    let isPlaying: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(phrase.phraseText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                if phrase.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.red)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(4)
            .background(buttonBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isPlaying ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var buttonBackground: some View {
        Group {
            if isPlaying {
                Color.green.opacity(0.3)
            } else {
                Color.white.opacity(0.95)
            }
        }
    }
}

/// Compact phrase button for smaller displays
struct CompactPhraseButton: View {
    let text: String
    let isPlaying: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(3)
                .background(isPlaying ? Color.yellow : Color.white.opacity(0.9))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

/// Add new phrase button
struct AddPhraseButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                Text("Add")
                    .font(.system(size: 10))
            }
            .foregroundColor(.cyan)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.3))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.cyan.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let phrase = Phrase(phraseText: "I need water", isFavorite: true)

    return VStack(spacing: 16) {
        HStack(spacing: 8) {
            PhraseButtonView(
                phrase: phrase,
                isPlaying: false,
                onTap: {}
            )
            .frame(height: 60)

            PhraseButtonView(
                phrase: phrase,
                isPlaying: true,
                onTap: {}
            )
            .frame(height: 60)
        }

        HStack(spacing: 8) {
            CompactPhraseButton(text: "Yes", isPlaying: false, onTap: {})
            CompactPhraseButton(text: "No", isPlaying: true, onTap: {})
            AddPhraseButton(onTap: {})
        }
        .frame(height: 40)
    }
    .padding()
    .background(Color.cyan)
}
