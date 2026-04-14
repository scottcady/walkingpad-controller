import Foundation

/// Manages connection mode selection and forwards operations to the appropriate service.
/// Acts as a facade that switches between HTTP bridge and direct Bluetooth connection.
@Observable
final class ConnectionManager {
    static let shared = ConnectionManager()

    // MARK: - Published State

    /// Current connection mode (stored in UserDefaults)
    var connectionMode: ConnectionMode {
        didSet {
            if oldValue != connectionMode {
                handleConnectionModeChange(from: oldValue)
            }
        }
    }

    /// Current connection state (forwarded from active service)
    var connectionState: ConnectionState {
        currentService.connectionState
    }

    /// Last status (forwarded from active service)
    var lastStatus: BridgeStatus? {
        currentService.lastStatus
    }

    /// Last error (forwarded from active service)
    var lastError: BridgeAPIError? {
        currentService.lastError
    }

    // MARK: - Services

    private let bridgeService = WalkingPadService.shared
    private let bluetoothService: (any PadConnectionService)? = nil // Will be BluetoothPadService.shared when implemented

    /// Returns the appropriate service based on current connection mode
    private var currentService: any PadConnectionService {
        switch connectionMode {
        case .bridge:
            return bridgeService
        case .bluetooth:
            // For now, fallback to bridge service until BluetoothPadService is implemented
            return bluetoothService ?? bridgeService
        }
    }

    // MARK: - Connection Management

    /// Checks if the pad is reachable and updates connection state
    func checkConnection() async {
        await currentService.checkConnection()
    }

    /// Disconnects from the current service
    func disconnect() async {
        await currentService.disconnect()
    }

    // MARK: - Status

    /// Fetches the current status from the WalkingPad
    func fetchStatus() async throws -> BridgeStatus {
        try await currentService.fetchStatus()
    }

    // MARK: - Control

    /// Starts the WalkingPad belt
    func start() async throws {
        try await currentService.start()
    }

    /// Stops the WalkingPad belt
    func stop() async throws {
        try await currentService.stop()
    }

    /// Sets the speed of the WalkingPad
    func setSpeed(_ kmh: Double) async throws {
        try await currentService.setSpeed(kmh)
    }

    // MARK: - Private Methods

    /// Handles connection mode changes by disconnecting from old service
    private func handleConnectionModeChange(from oldMode: ConnectionMode) {
        Task {
            // Disconnect from old service
            let oldService: any PadConnectionService
            switch oldMode {
            case .bridge:
                oldService = bridgeService
            case .bluetooth:
                oldService = bluetoothService ?? bridgeService
            }

            await oldService.disconnect()

            // Save to UserDefaults
            saveConnectionMode()

            // Connect to new service
            await checkConnection()
        }
    }

    /// Saves connection mode to UserDefaults
    private func saveConnectionMode() {
        if let encoded = try? JSONEncoder().encode(connectionMode) {
            UserDefaults.standard.set(encoded, forKey: "connectionMode")
        }
    }

    /// Loads connection mode from UserDefaults
    private static func loadConnectionMode() -> ConnectionMode {
        guard let data = UserDefaults.standard.data(forKey: "connectionMode"),
              let mode = try? JSONDecoder().decode(ConnectionMode.self, from: data) else {
            return .bridge // Default to bridge mode
        }
        return mode
    }

    // MARK: - Initialization

    private init() {
        self.connectionMode = Self.loadConnectionMode()
    }
}
