import SwiftUI

/// Banner showing the current connection state to the WalkingPad bridge.
/// Displays different states: disconnected, connecting, connected, or error.
struct ConnectionBanner: View {
    let connectionState: WalkingPadService.ConnectionState

    var body: some View {
        HStack(spacing: Theme.spacing.sm) {
            statusIcon
                .font(.system(size: 14, weight: .semibold))

            Text(statusText)
                .font(Theme.typography.subheadline)

            Spacer()

            if case .connecting = connectionState {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, Theme.spacing.md)
        .padding(.vertical, Theme.spacing.sm)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius.sm))
    }

    // MARK: - Computed Properties

    private var statusIcon: some View {
        Image(systemName: iconName)
            .foregroundStyle(iconColor)
    }

    private var iconName: String {
        switch connectionState {
        case .disconnected:
            return "wifi.slash"
        case .connecting:
            return "wifi"
        case .connected:
            return "wifi"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch connectionState {
        case .disconnected:
            return ColorTokens.textSecondary
        case .connecting:
            return ColorTokens.info
        case .connected:
            return ColorTokens.success
        case .error:
            return ColorTokens.error
        }
    }

    private var statusText: String {
        switch connectionState {
        case .disconnected:
            return "Not connected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error(let message):
            return message
        }
    }

    private var backgroundColor: Color {
        switch connectionState {
        case .disconnected:
            return ColorTokens.backgroundSecondary
        case .connecting:
            return ColorTokens.info.opacity(0.1)
        case .connected:
            return ColorTokens.success.opacity(0.1)
        case .error:
            return ColorTokens.error.opacity(0.1)
        }
    }
}

#Preview("Disconnected") {
    ConnectionBanner(connectionState: .disconnected)
        .padding()
}

#Preview("Connecting") {
    ConnectionBanner(connectionState: .connecting)
        .padding()
}

#Preview("Connected") {
    ConnectionBanner(connectionState: .connected)
        .padding()
}

#Preview("Error") {
    ConnectionBanner(connectionState: .error("Bridge unreachable"))
        .padding()
}
