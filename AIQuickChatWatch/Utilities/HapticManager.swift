import Foundation
import WatchKit

/// Manager for haptic feedback on Apple Watch
@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private init() {}

    /// Play haptic for button tap
    func tap() {
        WKInterfaceDevice.current().play(.click)
    }

    /// Play haptic for successful action
    func success() {
        WKInterfaceDevice.current().play(.success)
    }

    /// Play haptic for failed action
    func failure() {
        WKInterfaceDevice.current().play(.failure)
    }

    /// Play haptic when starting to speak
    func startSpeaking() {
        WKInterfaceDevice.current().play(.start)
    }

    /// Play haptic when done speaking
    func doneSpeaking() {
        WKInterfaceDevice.current().play(.stop)
    }

    /// Play directional up haptic (e.g., for navigation)
    func directionUp() {
        WKInterfaceDevice.current().play(.directionUp)
    }

    /// Play directional down haptic
    func directionDown() {
        WKInterfaceDevice.current().play(.directionDown)
    }

    /// Play notification haptic
    func notification() {
        WKInterfaceDevice.current().play(.notification)
    }

    /// Play retry haptic (for offline sync attempts)
    func retry() {
        WKInterfaceDevice.current().play(.retry)
    }
}
