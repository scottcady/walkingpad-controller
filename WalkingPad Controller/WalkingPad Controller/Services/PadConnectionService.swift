import Foundation

/// Protocol defining the interface for communicating with a WalkingPad.
/// Implemented by both BridgePadService (HTTP) and BluetoothPadService (direct BLE).
protocol PadConnectionService: AnyObject {
    // MARK: - Observable State

    /// Current connection state
    var connectionState: ConnectionState { get }

    /// Last successfully fetched status from the pad
    var lastStatus: BridgeStatus? { get }

    /// Last error encountered
    var lastError: BridgeAPIError? { get }

    // MARK: - Connection Management

    /// Checks if the pad is reachable and updates connection state.
    func checkConnection() async

    /// Disconnects from the pad (for cleanup)
    func disconnect() async

    // MARK: - Status

    /// Fetches the current status from the WalkingPad.
    /// - Returns: The current pad status
    /// - Throws: BridgeAPIError if the request fails
    func fetchStatus() async throws -> BridgeStatus

    // MARK: - Control

    /// Starts the WalkingPad belt.
    /// - Throws: BridgeAPIError if the request fails
    func start() async throws

    /// Stops the WalkingPad belt.
    /// - Throws: BridgeAPIError if the request fails
    func stop() async throws

    /// Sets the speed of the WalkingPad.
    /// - Parameter kmh: Speed in km/h (valid range: 0.5 - 6.0)
    /// - Throws: BridgeAPIError if the request fails
    func setSpeed(_ kmh: Double) async throws
}

// MARK: - Connection State

/// Connection state shared by all pad service implementations
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var statusText: String {
        switch self {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "Disconnected"
        case .error(let message): return message
        }
    }
}

// MARK: - Connection Mode

/// The type of connection to use for communicating with the WalkingPad
enum ConnectionMode: String, CaseIterable, Codable {
    case bluetooth = "bluetooth"
    case bridge = "bridge"

    var displayName: String {
        switch self {
        case .bluetooth: return "Bluetooth (Direct)"
        case .bridge: return "Bridge Server"
        }
    }

    var description: String {
        switch self {
        case .bluetooth: return "Connect directly to WalkingPad via Bluetooth"
        case .bridge: return "Connect through bridge server on Mac"
        }
    }
}
