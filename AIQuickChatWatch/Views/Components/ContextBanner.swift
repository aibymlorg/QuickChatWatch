import SwiftUI

/// Banner showing current context from iPhone
struct ContextBanner: View {
    let context: ReceivedContext

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: context.icon)
                .font(.caption2)

            Text(context.displayName)
                .font(.caption2)
                .fontWeight(.medium)

            if let placeName = context.placeName, !placeName.isEmpty {
                Text("•")
                    .font(.caption2)
                Text(placeName)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.8))
        .cornerRadius(8)
    }
}

/// Compact context indicator
struct ContextIndicator: View {
    let context: ReceivedContext

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "iphone")
                .font(.system(size: 8))
            Image(systemName: context.icon)
                .font(.system(size: 10))
        }
        .foregroundColor(.purple)
    }
}

/// Full context card for settings or detail view
struct ContextCard: View {
    let context: ReceivedContext
    let phrases: [String]
    let onPhraseTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: context.icon)
                    .font(.title3)
                    .foregroundColor(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)

                    if let placeName = context.placeName, !placeName.isEmpty {
                        Text(placeName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: "iphone")
                            .font(.system(size: 8))
                        Text("iPhone")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.secondary)

                    Text("\(Int(context.confidence * 100))%")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Phrases
            Text("Suggested Phrases")
                .font(.caption2)
                .foregroundColor(.secondary)

            ForEach(phrases.prefix(4), id: \.self) { phrase in
                Button {
                    onPhraseTap(phrase)
                } label: {
                    Text(phrase)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    VStack {
        ContextBanner(context: ReceivedContext(
            environmentType: "hospital",
            confidence: 0.85,
            source: "location",
            placeName: "City Hospital",
            sceneDescription: nil,
            timestamp: Date()
        ))

        ContextIndicator(context: ReceivedContext(
            environmentType: "restaurant",
            confidence: 0.9,
            source: "vision",
            placeName: nil,
            sceneDescription: nil,
            timestamp: Date()
        ))
    }
}
