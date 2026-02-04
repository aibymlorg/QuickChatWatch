import Foundation
import WatchKit

/// Service for handling background app refresh and tasks
@MainActor
final class BackgroundTaskService: ObservableObject {
    static let shared = BackgroundTaskService()

    @Published private(set) var lastRefreshDate: Date?
    @Published private(set) var isRefreshing: Bool = false

    /// Refresh interval in seconds (15 minutes)
    private let refreshInterval: TimeInterval = 15 * 60

    private init() {}

    // MARK: - Schedule Background Refresh

    /// Schedule the next background app refresh
    func scheduleBackgroundRefresh() {
        let preferredDate = Date().addingTimeInterval(refreshInterval)

        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: preferredDate,
            userInfo: nil
        ) { error in
            if let error = error {
                print("Failed to schedule background refresh: \(error)")
            } else {
                print("Background refresh scheduled for \(preferredDate)")
            }
        }
    }

    // MARK: - Handle Background Tasks

    /// Handle background refresh task
    func handleBackgroundRefresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        defer {
            isRefreshing = false
            lastRefreshDate = Date()
        }

        print("Starting background refresh...")

        // Check for pending sync
        let reachability = ReachabilityService.shared
        if reachability.isConnected {
            // Sync pending changes
            NotificationCenter.default.post(name: .syncRequested, object: nil)

            // Check for new instructions from server
            await checkForPendingInstructions()
        }

        // Schedule next refresh
        scheduleBackgroundRefresh()
    }

    /// Handle URL session background task
    func handleURLSessionTask(_ task: WKURLSessionRefreshBackgroundTask) {
        // Handle any background URL session completions
        task.setTaskCompletedWithSnapshot(false)
    }

    /// Handle snapshot refresh task
    func handleSnapshotRefresh(_ task: WKSnapshotRefreshBackgroundTask) {
        // Update the UI for the snapshot
        task.setTaskCompleted(
            restoredDefaultState: true,
            estimatedSnapshotExpiration: Date().addingTimeInterval(refreshInterval),
            userInfo: nil
        )
    }

    // MARK: - Check for Instructions

    private func checkForPendingInstructions() async {
        do {
            let instructions = try await APIClient.shared.getPendingInstructions()

            for instruction in instructions {
                await processServerInstruction(instruction)
            }
        } catch {
            print("Failed to fetch pending instructions: \(error)")
        }
    }

    private func processServerInstruction(_ instruction: ServerInstruction) async {
        switch instruction.type {
        case "context_pack":
            if let scenario = instruction.data["scenario"] as? String {
                NotificationCenter.default.post(
                    name: .contextPackRequested,
                    object: nil,
                    userInfo: ["scenario": scenario]
                )
            }

        case "phrases":
            if let phrases = instruction.data["phrases"] as? [String] {
                NotificationCenter.default.post(
                    name: .phrasesReceived,
                    object: nil,
                    userInfo: ["phrases": phrases]
                )
            }

        case "sync":
            NotificationCenter.default.post(name: .syncRequested, object: nil)

        default:
            print("Unknown instruction type: \(instruction.type)")
        }

        // Mark instruction as processed
        try? await APIClient.shared.markInstructionProcessed(instruction.id)
    }
}

// MARK: - Server Instruction Model

struct ServerInstruction: Codable, Identifiable {
    let id: String
    let type: String
    let data: [String: Any]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, data
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        createdAt = try container.decode(Date.self, forKey: .createdAt)

        // Decode data as dictionary
        if let dataDict = try? container.decode([String: String].self, forKey: .data) {
            data = dataDict
        } else if let dataArray = try? container.decode([String: [String]].self, forKey: .data) {
            data = dataArray
        } else {
            data = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
