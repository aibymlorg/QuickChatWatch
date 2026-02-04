import Foundation
import CoreLocation

/// Represents the detected environment context
struct EnvironmentContext: Codable, Equatable {
    let type: EnvironmentType
    let confidence: Double
    let source: DetectionSource
    let timestamp: Date
    let details: ContextDetails?

    enum EnvironmentType: String, Codable, CaseIterable {
        case hospital = "hospital"
        case clinic = "clinic"
        case pharmacy = "pharmacy"
        case restaurant = "restaurant"
        case cafe = "cafe"
        case grocery = "grocery"
        case retail = "retail"
        case bank = "bank"
        case publicTransport = "public_transport"
        case airport = "airport"
        case school = "school"
        case office = "office"
        case home = "home"
        case outdoors = "outdoors"
        case gym = "gym"
        case church = "church"
        case library = "library"
        case museum = "museum"
        case theater = "theater"
        case emergency = "emergency"
        case unknown = "unknown"

        var displayName: String {
            switch self {
            case .hospital: return "Hospital"
            case .clinic: return "Doctor's Clinic"
            case .pharmacy: return "Pharmacy"
            case .restaurant: return "Restaurant"
            case .cafe: return "Cafe"
            case .grocery: return "Grocery Store"
            case .retail: return "Shopping"
            case .bank: return "Bank"
            case .publicTransport: return "Public Transport"
            case .airport: return "Airport"
            case .school: return "School"
            case .office: return "Office"
            case .home: return "Home"
            case .outdoors: return "Outdoors"
            case .gym: return "Gym"
            case .church: return "Church"
            case .library: return "Library"
            case .museum: return "Museum"
            case .theater: return "Theater"
            case .emergency: return "Emergency"
            case .unknown: return "General"
            }
        }

        var icon: String {
            switch self {
            case .hospital, .clinic: return "cross.case.fill"
            case .pharmacy: return "pills.fill"
            case .restaurant: return "fork.knife"
            case .cafe: return "cup.and.saucer.fill"
            case .grocery: return "cart.fill"
            case .retail: return "bag.fill"
            case .bank: return "building.columns.fill"
            case .publicTransport: return "bus.fill"
            case .airport: return "airplane"
            case .school: return "graduationcap.fill"
            case .office: return "briefcase.fill"
            case .home: return "house.fill"
            case .outdoors: return "tree.fill"
            case .gym: return "figure.run"
            case .church: return "building.fill"
            case .library: return "books.vertical.fill"
            case .museum: return "building.columns"
            case .theater: return "theatermasks.fill"
            case .emergency: return "exclamationmark.triangle.fill"
            case .unknown: return "questionmark.circle.fill"
            }
        }

        /// Suggested phrases for each environment
        var suggestedPhrases: [String] {
            switch self {
            case .hospital, .clinic:
                return [
                    "I'm in pain",
                    "I need medication",
                    "Where is my doctor?",
                    "I need to use the bathroom",
                    "I'm feeling dizzy",
                    "Can I have water?",
                    "When can I go home?",
                    "Please call the nurse"
                ]
            case .pharmacy:
                return [
                    "I need to pick up my prescription",
                    "Do you have this medication?",
                    "What are the side effects?",
                    "How do I take this?",
                    "Is there a generic version?",
                    "I need help finding something"
                ]
            case .restaurant, .cafe:
                return [
                    "I'd like to order",
                    "Can I see the menu?",
                    "I have food allergies",
                    "No spicy food please",
                    "Can I have the check?",
                    "Where is the restroom?",
                    "Thank you",
                    "This is delicious"
                ]
            case .grocery, .retail:
                return [
                    "Where can I find...",
                    "Do you have this in stock?",
                    "Can you help me reach that?",
                    "I'm looking for...",
                    "Is this on sale?",
                    "Where is the checkout?",
                    "Can I pay with card?",
                    "Thank you for your help"
                ]
            case .bank:
                return [
                    "I need to make a deposit",
                    "I need to withdraw money",
                    "I'd like to speak to someone",
                    "Can you check my balance?",
                    "I need help with my account",
                    "Where do I sign?"
                ]
            case .publicTransport:
                return [
                    "Excuse me",
                    "Is this seat taken?",
                    "What stop is this?",
                    "Does this go to...",
                    "I need to get off here",
                    "Can you help me?",
                    "Thank you",
                    "Please give me space"
                ]
            case .airport:
                return [
                    "Where is my gate?",
                    "I need wheelchair assistance",
                    "Where is the restroom?",
                    "I need help with my bags",
                    "Where is baggage claim?",
                    "I'm looking for...",
                    "Thank you"
                ]
            case .school:
                return [
                    "I need help",
                    "Can you repeat that?",
                    "I don't understand",
                    "May I use the restroom?",
                    "I have a question",
                    "Thank you",
                    "Yes",
                    "No"
                ]
            case .office:
                return [
                    "Good morning",
                    "I have a meeting",
                    "Can we reschedule?",
                    "I need more time",
                    "I agree",
                    "I disagree",
                    "Can you repeat that?",
                    "Thank you"
                ]
            case .home:
                return [
                    "I need help",
                    "I'm hungry",
                    "I'm thirsty",
                    "I'm tired",
                    "Can we watch TV?",
                    "I love you",
                    "Thank you",
                    "Good night"
                ]
            case .gym:
                return [
                    "Can you help me?",
                    "Is this machine available?",
                    "How does this work?",
                    "I need water",
                    "Where are the weights?",
                    "Thank you"
                ]
            case .emergency:
                return [
                    "Help me!",
                    "Call 911",
                    "I need a doctor",
                    "I can't breathe",
                    "I'm having chest pain",
                    "I need my medication",
                    "Please help",
                    "Emergency"
                ]
            default:
                return [
                    "Hello",
                    "Yes",
                    "No",
                    "Thank you",
                    "Help me",
                    "Excuse me",
                    "I need help",
                    "Goodbye"
                ]
            }
        }
    }

    enum DetectionSource: String, Codable {
        case vision = "vision"          // Camera scene classification
        case location = "location"      // GPS + Places
        case calendar = "calendar"      // Calendar events
        case audio = "audio"            // Ambient sound
        case manual = "manual"          // User selected
        case siri = "siri"              // Siri/Apple Intelligence
    }

    struct ContextDetails: Codable, Equatable {
        let placeName: String?
        let address: String?
        let calendarEvent: String?
        let sceneDescription: String?
    }
}

/// Message sent to Apple Watch
struct WatchContextMessage: Codable {
    let type: String = "context_update"
    let environment: EnvironmentContext
    let phrases: [String]
    let timestamp: Date

    init(environment: EnvironmentContext) {
        self.environment = environment
        self.phrases = environment.type.suggestedPhrases
        self.timestamp = Date()
    }

    func toDictionary() -> [String: Any] {
        [
            "type": type,
            "environmentType": environment.type.rawValue,
            "confidence": environment.confidence,
            "source": environment.source.rawValue,
            "phrases": phrases,
            "timestamp": timestamp.timeIntervalSince1970,
            "placeName": environment.details?.placeName ?? "",
            "sceneDescription": environment.details?.sceneDescription ?? ""
        ]
    }
}
