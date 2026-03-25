import Foundation

/// Response from GET /status endpoint on the bridge.
struct BridgeStatus: Codable, Equatable {
    /// Elapsed time in seconds since pad powered on
    let time: Int

    /// Distance in kilometers
    let distance: Double

    /// Total step count
    let steps: Int

    /// Current speed in km/h
    let speed: Double

    /// Pad state as raw integer (use `padState` for typed access)
    let state: Int

    /// Pad mode as raw integer (use `padMode` for typed access)
    let mode: Int

    /// Convenience flag: true when state == 1 (running)
    let running: Bool

    // MARK: - Typed Accessors

    /// Typed pad state
    var padState: PadState {
        PadState(rawValue: state) ?? .unknown
    }

    /// Typed pad mode
    var padMode: PadMode {
        PadMode(rawValue: mode) ?? .unknown
    }
}

// MARK: - Pad Mode

/// Operating mode of the WalkingPad
enum PadMode: Int, Codable {
    case auto = 0
    case manual = 1
    case standby = 2
    case unknown = -1

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .manual: return "Manual"
        case .standby: return "Standby"
        case .unknown: return "Unknown"
        }
    }
}
