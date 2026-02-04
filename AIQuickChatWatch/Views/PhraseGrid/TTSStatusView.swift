import SwiftUI

/// View showing the current TTS status
struct TTSStatusView: View {
    let status: TTSStatus

    var body: some View {
        HStack(spacing: 4) {
            statusIcon
            statusText
        }
        .font(.caption2)
        .foregroundColor(statusColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.2))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .idle:
            Image(systemName: "speaker.fill")
        case .loading:
            ProgressView()
                .scaleEffect(0.6)
        case .playing:
            Image(systemName: "speaker.wave.3.fill")
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
        }
    }

    private var statusText: Text {
        switch status {
        case .idle:
            return Text("Ready")
        case .loading:
            return Text("Loading...")
        case .playing:
            return Text("Playing")
        case .error:
            return Text("Error")
        }
    }

    private var statusColor: Color {
        switch status {
        case .idle:
            return .gray
        case .loading:
            return .blue
        case .playing:
            return .green
        case .error:
            return .red
        }
    }
}

/// Compact status indicator (just icon)
struct TTSStatusIndicator: View {
    let status: TTSStatus

    var body: some View {
        Group {
            switch status {
            case .idle:
                EmptyView()
            case .loading:
                ProgressView()
                    .scaleEffect(0.5)
            case .playing:
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.green)
                    .font(.caption2)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.caption2)
            }
        }
    }
}

/// Animated speaking indicator
struct SpeakingWaveView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.green)
                    .frame(width: 3, height: animating ? 12 : 4)
                    .animation(
                        Animation.easeInOut(duration: 0.4)
                            .repeatForever()
                            .delay(Double(i) * 0.1),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TTSStatusView(status: .idle)
        TTSStatusView(status: .loading)
        TTSStatusView(status: .playing)
        TTSStatusView(status: .error)

        Divider()

        HStack(spacing: 20) {
            TTSStatusIndicator(status: .loading)
            TTSStatusIndicator(status: .playing)
            TTSStatusIndicator(status: .error)
        }

        Divider()

        SpeakingWaveView()
    }
    .padding()
}
