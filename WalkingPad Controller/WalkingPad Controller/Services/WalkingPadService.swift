import Foundation

/// Service for communicating with the WalkingPad bridge API.
/// Manages connection state and provides methods for controlling the treadmill.
@Observable
final class WalkingPadService: PadConnectionService {
    static let shared = WalkingPadService()

    // MARK: - Published State

    /// Current connection state to the bridge
    private(set) var connectionState: ConnectionState = .disconnected

    /// Last successfully fetched status from the pad
    private(set) var lastStatus: BridgeStatus?

    /// Last error encountered
    private(set) var lastError: BridgeAPIError?

    // MARK: - Configuration

    /// Timeout interval for network requests (5 seconds)
    private let timeoutInterval: TimeInterval = 5.0

    /// URLSession configured with timeout
    private let session: URLSession

    /// Reference to settings service for bridge URL
    private let settings = SettingsService.shared

    // MARK: - Public API

    /// Checks if the bridge is reachable and updates connection state.
    /// Call this when the app becomes active or when settings change.
    func checkConnection() async {
        connectionState = .connecting
        lastError = nil

        do {
            let status = try await fetchStatus()
            lastStatus = status
            connectionState = .connected
        } catch let error as BridgeAPIError {
            lastError = error
            connectionState = .error(error.errorDescription ?? "Unknown error")
        } catch {
            let bridgeError = BridgeAPIError.unknown(error.localizedDescription)
            lastError = bridgeError
            connectionState = .error(bridgeError.errorDescription ?? "Unknown error")
        }
    }

    /// Fetches the current status from the WalkingPad.
    /// - Returns: The current pad status
    /// - Throws: BridgeAPIError if the request fails
    func fetchStatus() async throws -> BridgeStatus {
        let data = try await performRequest(endpoint: "/status", method: "GET")

        do {
            let status = try JSONDecoder().decode(BridgeStatus.self, from: data)
            lastStatus = status
            return status
        } catch {
            throw BridgeAPIError.decodingError
        }
    }

    /// Starts the WalkingPad belt.
    /// - Throws: BridgeAPIError if the request fails
    func start() async throws {
        _ = try await performRequest(endpoint: "/start", method: "POST")
    }

    /// Stops the WalkingPad belt.
    /// - Throws: BridgeAPIError if the request fails
    func stop() async throws {
        _ = try await performRequest(endpoint: "/stop", method: "POST")
    }

    /// Sets the speed of the WalkingPad.
    /// - Parameter kmh: Speed in km/h (valid range: 0.5 - 6.0)
    /// - Throws: BridgeAPIError if the request fails
    func setSpeed(_ kmh: Double) async throws {
        // Clamp to valid range
        let clampedSpeed = min(max(kmh, 0.5), 6.0)

        // Convert to raw value (multiply by 10)
        let rawValue = Int(clampedSpeed * 10)

        _ = try await performRequest(endpoint: "/speed/\(rawValue)", method: "POST")
    }

    /// Disconnects from the bridge (no-op for HTTP, just updates state)
    func disconnect() async {
        connectionState = .disconnected
    }

    // MARK: - Private Methods

    /// Builds the URL for an endpoint
    private func buildURL(endpoint: String) throws -> URL {
        guard let baseURLString = settings.bridgeURL else {
            throw BridgeAPIError.urlNotConfigured
        }

        guard let url = URL(string: baseURLString + endpoint) else {
            throw BridgeAPIError.invalidURL
        }

        return url
    }

    /// Performs an HTTP request to the bridge
    private func performRequest(endpoint: String, method: String) async throws -> Data {
        let url = try buildURL(endpoint: endpoint)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeoutInterval

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw mapURLError(error)
        } catch {
            throw BridgeAPIError.unknown(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BridgeAPIError.unknown("Invalid response type")
        }

        try handleHTTPStatus(httpResponse, data: data)

        return data
    }

    /// Maps URLError to BridgeAPIError
    private func mapURLError(_ error: URLError) -> BridgeAPIError {
        switch error.code {
        case .timedOut:
            return .timeout
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
            return .unreachable
        default:
            return .unknown(error.localizedDescription)
        }
    }

    /// Handles HTTP status codes and throws appropriate errors
    private func handleHTTPStatus(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200..<300:
            // Success
            return

        case 400:
            let message = extractErrorMessage(from: data)
            if message.lowercased().contains("not connected") {
                throw BridgeAPIError.padNotConnected
            }
            throw BridgeAPIError.bridgeError(statusCode: 400, message: message)

        case 404:
            let message = extractErrorMessage(from: data)
            if message.lowercased().contains("not found") {
                throw BridgeAPIError.padNotFound
            }
            throw BridgeAPIError.bridgeError(statusCode: 404, message: message)

        case 500:
            let message = extractErrorMessage(from: data)
            if message.lowercased().contains("ble") || message.lowercased().contains("bluetooth") {
                throw BridgeAPIError.bleFailure
            }
            throw BridgeAPIError.bridgeError(statusCode: 500, message: message)

        default:
            let message = extractErrorMessage(from: data)
            throw BridgeAPIError.bridgeError(statusCode: response.statusCode, message: message)
        }
    }

    /// Extracts error message from response data
    private func extractErrorMessage(from data: Data) -> String {
        if let errorResponse = try? JSONDecoder().decode(BridgeErrorResponse.self, from: data) {
            return errorResponse.detail
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }

    // MARK: - Initialization

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 5.0
        self.session = URLSession(configuration: config)
    }
}
