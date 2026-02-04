import Foundation
import Network
import Combine

/// Service for monitoring network connectivity status
@MainActor
final class ReachabilityService: ObservableObject {
    static let shared = ReachabilityService()

    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.aiquickchat.reachability")

    enum ConnectionType {
        case wifi
        case cellular
        case wiredEthernet
        case unknown
        case none

        var description: String {
            switch self {
            case .wifi: return "WiFi"
            case .cellular: return "Cellular"
            case .wiredEthernet: return "Wired"
            case .unknown: return "Unknown"
            case .none: return "No Connection"
            }
        }

        var isAvailable: Bool {
            self != .none
        }
    }

    private init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.updateStatus(from: path)
            }
        }
        monitor.start(queue: queue)
    }

    private func stopMonitoring() {
        monitor.cancel()
    }

    private func updateStatus(from path: NWPath) {
        isConnected = path.status == .satisfied

        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else if path.status == .satisfied {
            connectionType = .unknown
        } else {
            connectionType = .none
        }
    }

    /// Check if expensive network (cellular) is being used
    var isExpensive: Bool {
        monitor.currentPath.isExpensive
    }

    /// Check if constrained network
    var isConstrained: Bool {
        monitor.currentPath.isConstrained
    }

    /// Wait for network connection with timeout
    func waitForConnection(timeout: TimeInterval = 10) async -> Bool {
        if isConnected { return true }

        return await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                cancellable?.cancel()
                continuation.resume(returning: false)
            }

            cancellable = $isConnected
                .filter { $0 }
                .first()
                .sink { _ in
                    timeoutTask.cancel()
                    continuation.resume(returning: true)
                }
        }
    }
}
