import SwiftUI

struct ContentView: View {
    @EnvironmentObject var watchConnector: WatchConnectorService
    @EnvironmentObject var environmentDetector: EnvironmentDetectionService

    @State private var showManualPicker = false
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Watch Connection Status
                    watchStatusCard

                    // Current Environment
                    currentEnvironmentCard

                    // Detection Sources
                    detectionSourcesCard

                    // Quick Actions
                    quickActionsCard

                    // Manual Override
                    manualOverrideCard
                }
                .padding()
            }
            .navigationTitle("QuickChat")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCamera = true
                    } label: {
                        Image(systemName: "camera.fill")
                    }
                }
            }
            .sheet(isPresented: $showManualPicker) {
                EnvironmentPickerView()
            }
            .sheet(isPresented: $showCamera) {
                CameraAnalysisView()
            }
        }
    }

    // MARK: - Cards

    private var watchStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "applewatch")
                    .font(.title2)
                    .foregroundColor(watchConnector.isReachable ? .green : .gray)

                VStack(alignment: .leading) {
                    Text("Apple Watch")
                        .font(.headline)
                    Text(watchStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Circle()
                    .fill(watchConnector.isReachable ? Color.green : Color.orange)
                    .frame(width: 12, height: 12)
            }

            if !watchConnector.isWatchAppInstalled {
                Text("Please install QuickChat on your Apple Watch")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var watchStatusText: String {
        if !watchConnector.isWatchAppInstalled {
            return "App not installed"
        } else if watchConnector.isReachable {
            return "Connected"
        } else {
            return "Not reachable"
        }
    }

    private var currentEnvironmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Environment")
                .font(.headline)

            if let context = environmentDetector.currentContext {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.2))
                            .frame(width: 60, height: 60)

                        Image(systemName: context.type.icon)
                            .font(.title)
                            .foregroundColor(.cyan)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.type.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)

                        if let placeName = context.details?.placeName {
                            Text(placeName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Confidence: \(Int(context.confidence * 100))%")
                                .font(.caption2)

                            Text("•")

                            Text(context.source.rawValue.capitalized)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                // Phrases preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested Phrases")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    FlowLayout(spacing: 6) {
                        ForEach(context.type.suggestedPhrases.prefix(6), id: \.self) { phrase in
                            Text(phrase)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.cyan.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }

                // Send to Watch button
                Button {
                    watchConnector.sendContext(context)
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Send to Watch")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.cyan)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "location.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)

                    Text("No environment detected")
                        .foregroundColor(.secondary)

                    Button("Detect Now") {
                        environmentDetector.startMonitoring()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var detectionSourcesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detection Sources")
                .font(.headline)

            HStack(spacing: 16) {
                DetectionSourceBadge(
                    icon: "location.fill",
                    label: "Location",
                    isActive: environmentDetector.detectionSources[.location] ?? false
                )

                DetectionSourceBadge(
                    icon: "camera.fill",
                    label: "Camera",
                    isActive: environmentDetector.detectionSources[.vision] ?? false
                )

                DetectionSourceBadge(
                    icon: "calendar",
                    label: "Calendar",
                    isActive: environmentDetector.detectionSources[.calendar] ?? false
                )
            }

            if let lastUpdate = environmentDetector.lastUpdate {
                Text("Last updated: \(lastUpdate, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "exclamationmark.triangle.fill",
                    label: "Emergency",
                    color: .red
                ) {
                    watchConnector.sendEmergencyAlert()
                }

                QuickActionButton(
                    icon: "camera.viewfinder",
                    label: "Scan",
                    color: .blue
                ) {
                    environmentDetector.analyzeCurrentScene()
                }

                QuickActionButton(
                    icon: "arrow.clockwise",
                    label: "Refresh",
                    color: .green
                ) {
                    environmentDetector.startMonitoring()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var manualOverrideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual Override")
                .font(.headline)

            Text("Tap to manually select an environment")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(EnvironmentContext.EnvironmentType.allCases.prefix(8), id: \.self) { type in
                        EnvironmentButton(type: type) {
                            environmentDetector.setManualContext(type)
                        }
                    }

                    Button {
                        showManualPicker = true
                    } label: {
                        VStack {
                            Image(systemName: "ellipsis")
                                .font(.title2)
                            Text("More")
                                .font(.caption2)
                        }
                        .frame(width: 70, height: 70)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views

struct DetectionSourceBadge: View {
    let icon: String
    let label: String
    let isActive: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isActive ? .green : .gray)

            Text(label)
                .font(.caption2)
                .foregroundColor(isActive ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isActive ? Color.green.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(10)
        }
    }
}

struct EnvironmentButton: View {
    let type: EnvironmentContext.EnvironmentType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.title2)
                Text(type.displayName)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(width: 70, height: 70)
            .background(Color.cyan.opacity(0.1))
            .foregroundColor(.cyan)
            .cornerRadius(12)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, proposal: proposal).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(sizes: sizes, proposal: proposal).offsets

        for (subview, offset) in zip(subviews, offsets) {
            subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func layout(sizes: [CGSize], proposal: ProposedViewSize) -> (offsets: [CGPoint], size: CGSize) {
        let width = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for size in sizes {
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            offsets.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return (offsets, CGSize(width: width, height: currentY + lineHeight))
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectorService.shared)
        .environmentObject(EnvironmentDetectionService.shared)
}
