import SwiftUI

/// iPhone companion app settings
struct PhoneSettingsView: View {
    @EnvironmentObject var environmentDetector: EnvironmentDetectionService
    @EnvironmentObject var watchConnector: WatchConnectorService

    @AppStorage("autoDetectionEnabled") private var autoDetectionEnabled = true
    @AppStorage("locationDetectionEnabled") private var locationDetectionEnabled = true
    @AppStorage("calendarDetectionEnabled") private var calendarDetectionEnabled = true
    @AppStorage("autoSendToWatch") private var autoSendToWatch = true

    var body: some View {
        NavigationStack {
            List {
                // Watch Connection Status
                Section {
                    HStack {
                        Image(systemName: watchConnector.isWatchReachable ? "applewatch" : "applewatch.slash")
                            .foregroundColor(watchConnector.isWatchReachable ? .green : .gray)

                        VStack(alignment: .leading) {
                            Text("Apple Watch")
                                .font(.body)
                            Text(watchConnector.isWatchReachable ? "Connected" : "Not reachable")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if watchConnector.isWatchReachable {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }

                    if watchConnector.isWatchPaired && !watchConnector.isWatchReachable {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Watch is paired but not currently reachable. Make sure your watch is nearby and awake.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Watch Connection")
                }

                // Detection Settings
                Section {
                    Toggle("Auto Detection", isOn: $autoDetectionEnabled)
                        .onChange(of: autoDetectionEnabled) { _, newValue in
                            if newValue {
                                environmentDetector.startMonitoring()
                            } else {
                                environmentDetector.stopMonitoring()
                            }
                        }

                    if autoDetectionEnabled {
                        Toggle("Location-based", isOn: $locationDetectionEnabled)
                            .padding(.leading)

                        Toggle("Calendar-based", isOn: $calendarDetectionEnabled)
                            .padding(.leading)
                    }
                } header: {
                    Text("Environment Detection")
                } footer: {
                    Text("When enabled, the app will automatically detect your environment and suggest appropriate phrases.")
                }

                // Watch Sync Settings
                Section {
                    Toggle("Auto-send to Watch", isOn: $autoSendToWatch)
                } header: {
                    Text("Watch Sync")
                } footer: {
                    Text("Automatically send context-appropriate phrases to your Apple Watch when environment changes.")
                }

                // Current Context Info
                if let context = environmentDetector.currentContext {
                    Section {
                        HStack {
                            Image(systemName: context.type.icon)
                                .font(.title2)
                                .foregroundColor(.cyan)
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(context.type.displayName)
                                    .font(.headline)

                                if let details = context.details {
                                    if let placeName = details.placeName {
                                        Text(placeName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Text("Confidence: \(Int(context.confidence * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text(context.source.rawValue.capitalized)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.cyan.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }

                        Button {
                            watchConnector.sendContextToWatch(context, phrases: context.type.suggestedPhrases)
                        } label: {
                            HStack {
                                Image(systemName: "arrow.right.circle")
                                Text("Send to Watch Now")
                            }
                        }
                        .disabled(!watchConnector.isWatchReachable)
                    } header: {
                        Text("Current Context")
                    }
                }

                // Permissions
                Section {
                    NavigationLink {
                        PermissionsView()
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.blue)
                            Text("Permissions")
                        }
                    }
                } header: {
                    Text("Privacy")
                }

                // About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://aiquickchat.com/support")!) {
                        HStack {
                            Text("Help & Support")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

/// Permissions management view
struct PermissionsView: View {
    @State private var locationStatus: String = "Unknown"
    @State private var cameraStatus: String = "Unknown"
    @State private var calendarStatus: String = "Unknown"

    var body: some View {
        List {
            Section {
                PermissionRow(
                    icon: "location.fill",
                    title: "Location",
                    status: locationStatus,
                    description: "Used to detect your environment"
                )

                PermissionRow(
                    icon: "camera.fill",
                    title: "Camera",
                    status: cameraStatus,
                    description: "Used for scene analysis"
                )

                PermissionRow(
                    icon: "calendar",
                    title: "Calendar",
                    status: calendarStatus,
                    description: "Used for event-based context"
                )
            } footer: {
                Text("Tap to open Settings and manage permissions.")
            }

            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Open Settings")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Permissions")
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        // Check location
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways:
            locationStatus = "Always"
        case .authorizedWhenInUse:
            locationStatus = "When In Use"
        case .denied:
            locationStatus = "Denied"
        case .restricted:
            locationStatus = "Restricted"
        case .notDetermined:
            locationStatus = "Not Set"
        @unknown default:
            locationStatus = "Unknown"
        }

        // Check camera
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraStatus = "Allowed"
        case .denied:
            cameraStatus = "Denied"
        case .restricted:
            cameraStatus = "Restricted"
        case .notDetermined:
            cameraStatus = "Not Set"
        @unknown default:
            cameraStatus = "Unknown"
        }

        // Check calendar
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            calendarStatus = "Allowed"
        case .denied:
            calendarStatus = "Denied"
        case .restricted:
            calendarStatus = "Restricted"
        case .notDetermined:
            calendarStatus = "Not Set"
        case .writeOnly:
            calendarStatus = "Write Only"
        @unknown default:
            calendarStatus = "Unknown"
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let status: String
    let description: String

    var statusColor: Color {
        switch status {
        case "Always", "Allowed", "When In Use":
            return .green
        case "Denied", "Restricted":
            return .red
        default:
            return .orange
        }
    }

    var body: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.cyan)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(status)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
        }
    }
}

import CoreLocation
import AVFoundation
import EventKit

#Preview {
    PhoneSettingsView()
        .environmentObject(EnvironmentDetectionService.shared)
        .environmentObject(WatchConnectorService.shared)
}
