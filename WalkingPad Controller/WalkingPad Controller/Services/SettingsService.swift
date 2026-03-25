import Foundation

final class SettingsService {
    static let shared = SettingsService()

    private let defaults = UserDefaults.standard

    // MARK: - Keys
    private enum Keys {
        static let bridgeURL = "bridgeURL"
    }

    // MARK: - Bridge URL
    var bridgeURL: String? {
        get { defaults.string(forKey: Keys.bridgeURL) }
        set { defaults.set(newValue, forKey: Keys.bridgeURL) }
    }

    // MARK: - Validation

    /// Validates a bridge URL string.
    /// Returns nil if valid, or an error message if invalid.
    func validateBridgeURL(_ urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return "URL cannot be empty"
        }

        // Must start with http:// or https://
        guard trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") else {
            return "URL must start with http:// or https://"
        }

        // Attempt to parse as URL
        guard let url = URL(string: trimmed) else {
            return "Invalid URL format"
        }

        // Must have a host
        guard let host = url.host, !host.isEmpty else {
            return "URL must include a host (e.g., 192.168.1.100)"
        }

        // Port is optional but if present must be valid
        if let portString = trimmed.components(separatedBy: ":").last,
           let colonIndex = trimmed.lastIndex(of: ":"),
           colonIndex > trimmed.index(trimmed.startIndex, offsetBy: 6) { // After "http://"
            // Extract potential port (everything after last colon until / or end)
            let afterColon = trimmed[trimmed.index(after: colonIndex)...]
            let portPart = afterColon.prefix(while: { $0.isNumber })
            if !portPart.isEmpty {
                guard let port = Int(portPart), port > 0, port <= 65535 else {
                    return "Port must be between 1 and 65535"
                }
            }
        }

        return nil
    }

    /// Normalizes a bridge URL by ensuring it has the correct format.
    /// Removes trailing slashes.
    func normalizeBridgeURL(_ urlString: String) -> String {
        var normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove trailing slashes
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }

        return normalized
    }

    private init() {}
}
