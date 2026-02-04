import SwiftUI

/// Banner showing offline status
struct OfflineBanner: View {
    @ObservedObject var reachability = ReachabilityService.shared

    var body: some View {
        if !reachability.isConnected {
            HStack(spacing: 4) {
                Image(systemName: "wifi.slash")
                    .font(.caption2)
                Text("Offline")
                    .font(.caption2)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange)
            .cornerRadius(8)
        }
    }
}

/// Compact offline indicator for status bar
struct OfflineIndicator: View {
    @ObservedObject var reachability = ReachabilityService.shared

    var body: some View {
        if !reachability.isConnected {
            Image(systemName: "wifi.slash")
                .font(.caption2)
                .foregroundColor(.orange)
        }
    }
}

#Preview {
    VStack {
        OfflineBanner()
        OfflineIndicator()
    }
}
