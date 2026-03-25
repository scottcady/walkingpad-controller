import Foundation

/// Errors that can occur when communicating with the bridge API
enum BridgeAPIError: Error, Equatable {
    /// Bridge URL is not configured in settings
    case urlNotConfigured

    /// Bridge URL is invalid
    case invalidURL

    /// Network request timed out
    case timeout

    /// Bridge is not reachable (network error)
    case unreachable

    /// Bridge returned an error response
    case bridgeError(statusCode: Int, message: String)

    /// WalkingPad not found during Bluetooth scan
    case padNotFound

    /// WalkingPad is not connected to the bridge
    case padNotConnected

    /// Bluetooth communication failure
    case bleFailure

    /// Failed to decode response from bridge
    case decodingError

    /// Unknown error occurred
    case unknown(String)
}

// MARK: - User-Friendly Messages

extension BridgeAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .urlNotConfigured:
            return "Bridge URL not configured"
        case .invalidURL:
            return "Invalid bridge URL"
        case .timeout:
            return "Connection timed out"
        case .unreachable:
            return "Bridge unreachable"
        case .bridgeError(_, let message):
            return message
        case .padNotFound:
            return "WalkingPad not found"
        case .padNotConnected:
            return "WalkingPad not connected"
        case .bleFailure:
            return "Bluetooth error"
        case .decodingError:
            return "Invalid response"
        case .unknown(let message):
            return message
        }
    }

    /// Detailed description for debugging or detailed error display
    var detailedDescription: String {
        switch self {
        case .urlNotConfigured:
            return "Please configure the bridge URL in Settings."
        case .invalidURL:
            return "The bridge URL is not valid. Check your settings."
        case .timeout:
            return "The bridge did not respond in time. Check that the bridge is running."
        case .unreachable:
            return "Cannot reach the bridge. Check your network connection and that the bridge is running."
        case .bridgeError(let statusCode, let message):
            return "Bridge error (\(statusCode)): \(message)"
        case .padNotFound:
            return "Could not find the WalkingPad during Bluetooth scan. Make sure it's powered on and nearby."
        case .padNotConnected:
            return "The bridge is not connected to the WalkingPad. Try restarting the bridge."
        case .bleFailure:
            return "Bluetooth communication failed. Try restarting the WalkingPad and bridge."
        case .decodingError:
            return "Received an unexpected response from the bridge."
        case .unknown(let message):
            return message
        }
    }

    /// Whether this error suggests retrying might help
    var isRetryable: Bool {
        switch self {
        case .timeout, .unreachable, .bleFailure:
            return true
        case .urlNotConfigured, .invalidURL, .padNotFound, .padNotConnected, .decodingError, .bridgeError, .unknown:
            return false
        }
    }
}

// MARK: - Error Response Decoding

/// Error response format from the bridge API
struct BridgeErrorResponse: Codable {
    let detail: String
}
