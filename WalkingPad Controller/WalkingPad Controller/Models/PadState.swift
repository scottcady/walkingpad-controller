import Foundation

/// Belt state of the WalkingPad
enum PadState: Int, Codable {
    case idle = 0
    case running = 1
    case standby = 5
    case starting = 9
    case unknown = -1

    /// Human-readable name for display in UI
    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .running: return "Running"
        case .standby: return "Standby"
        case .starting: return "Starting"
        case .unknown: return "Unknown"
        }
    }

    /// Whether the belt is actively moving
    var isActive: Bool {
        switch self {
        case .running, .starting:
            return true
        case .idle, .standby, .unknown:
            return false
        }
    }

    /// Whether the pad is in a state where it can be started
    var canStart: Bool {
        switch self {
        case .idle, .standby:
            return true
        case .running, .starting, .unknown:
            return false
        }
    }

    /// Whether the pad is in a state where it can be stopped
    var canStop: Bool {
        switch self {
        case .running, .starting:
            return true
        case .idle, .standby, .unknown:
            return false
        }
    }
}
