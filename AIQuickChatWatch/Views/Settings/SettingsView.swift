import SwiftUI
import SwiftData

/// Main settings view
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @ObservedObject private var reachability = ReachabilityService.shared
    @ObservedObject private var syncService = SyncService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // AI Toggle
                    aiToggleSection

                    // Language
                    languageSection

                    // Response Mode
                    responseModeSection

                    // Voice Speed
                    voiceSpeedSection

                    // Sync Status
                    syncStatusSection

                    // Account
                    accountSection
                }
                .padding()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.modelContext = modelContext
                viewModel.loadSettings()
            }
        }
    }

    // MARK: - Sections

    private var aiToggleSection: some View {
        SettingsRow(
            icon: "sparkles",
            iconColor: .purple,
            title: "AI Function"
        ) {
            Toggle("", isOn: Binding(
                get: { viewModel.settings?.aiEnabled ?? true },
                set: { viewModel.toggleAI($0) }
            ))
            .labelsHidden()
        }
    }

    private var languageSection: some View {
        NavigationLink {
            LanguagePickerView(viewModel: viewModel)
        } label: {
            SettingsRow(
                icon: "globe",
                iconColor: .blue,
                title: "Language"
            ) {
                HStack {
                    Text(viewModel.settings?.language ?? "English")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var responseModeSection: some View {
        NavigationLink {
            ResponseModeView(viewModel: viewModel)
        } label: {
            SettingsRow(
                icon: "location.fill",
                iconColor: .orange,
                title: "Environment"
            ) {
                HStack {
                    Text(currentModeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var currentModeName: String {
        let mode = viewModel.settings?.responseMode ?? "general"
        return UserSettings.responseModes.first { $0.name == mode }?.description ?? "General"
    }

    private var voiceSpeedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsRow(
                icon: "speaker.wave.2.fill",
                iconColor: .cyan,
                title: "Voice Speed"
            ) {
                Text(String(format: "%.1fx", viewModel.settings?.voiceSpeed ?? 1.0))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Slider(
                value: Binding(
                    get: { viewModel.settings?.voiceSpeed ?? 1.0 },
                    set: { viewModel.updateVoiceSpeed($0) }
                ),
                in: 0.5...2.0,
                step: 0.1
            )
            .tint(.cyan)
        }
    }

    private var syncStatusSection: some View {
        VStack(spacing: 8) {
            SettingsRow(
                icon: reachability.isConnected ? "icloud.fill" : "icloud.slash.fill",
                iconColor: reachability.isConnected ? .green : .orange,
                title: "Sync Status"
            ) {
                if syncService.isSyncing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text(reachability.isConnected ? "Connected" : "Offline")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if syncService.pendingChanges > 0 {
                Text("\(syncService.pendingChanges) pending changes")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }

            if let lastSync = syncService.lastSyncDate {
                Text("Last sync: \(lastSync, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Button {
                Task {
                    await viewModel.sync()
                }
            } label: {
                Text("Sync Now")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!reachability.isConnected || syncService.isSyncing)
        }
    }

    private var accountSection: some View {
        VStack(spacing: 8) {
            if authViewModel.isAuthenticated {
                SettingsRow(
                    icon: "person.circle.fill",
                    iconColor: .blue,
                    title: "Account"
                ) {
                    Text(authViewModel.user?.email ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Button {
                    Task {
                        await authViewModel.logout()
                    }
                } label: {
                    Text("Sign Out")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                NavigationLink {
                    LoginView()
                } label: {
                    SettingsRow(
                        icon: "person.crop.circle.badge.plus",
                        iconColor: .cyan,
                        title: "Sign In"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Reusable settings row
struct SettingsRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
                .frame(width: 24)

            Text(title)
                .font(.caption)
                .foregroundColor(.primary)

            Spacer()

            content()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Phrase.self, UserSettings.self, UsageLog.self], inMemory: true)
}
