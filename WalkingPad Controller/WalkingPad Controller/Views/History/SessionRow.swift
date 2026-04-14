import SwiftUI

/// Row component for displaying a walking session in the history list.
/// Placeholder for Phase 7 implementation.
struct SessionRow: View {
    let date: Date
    let durationSeconds: Int
    let distanceKm: Double  // Stored in km, displayed in miles
    let steps: Int
    let syncedToHealth: Bool

    var body: some View {
        HStack(spacing: Theme.spacing.md) {
            // Date and time
            VStack(alignment: .leading, spacing: Theme.spacing.xxs) {
                Text(formattedDate)
                    .font(Theme.typography.headline)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text(formattedTime)
                    .font(Theme.typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Spacer()

            // Metrics
            HStack(spacing: Theme.spacing.md) {
                MetricLabel(value: formattedDuration, label: "min")
                MetricLabel(value: formattedDistance, label: "mi")
                MetricLabel(value: "\(steps)", label: "steps")
            }

            // Health sync indicator
            if syncedToHealth {
                Image(systemName: "heart.fill")
                    .foregroundStyle(ColorTokens.error)
                    .font(.caption)
            }
        }
        .padding(.vertical, Theme.spacing.xs)
    }

    // MARK: - Formatted Values

    private var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private var formattedTime: String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private var formattedDuration: String {
        let minutes = durationSeconds / 60
        return "\(minutes)"
    }

    private var formattedDistance: String {
        // Convert km to miles for display
        let distanceMiles = distanceKm / 1.60934
        return String(format: "%.2f", distanceMiles)
    }
}

// MARK: - Metric Label

private struct MetricLabel: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 0) {
            Text(value)
                .font(Theme.typography.subheadlineBold)
                .foregroundStyle(ColorTokens.textPrimary)
                .monospacedDigit()

            Text(label)
                .font(Theme.typography.caption2)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }
}

#Preview {
    List {
        SessionRow(
            date: Date(),
            durationSeconds: 1800,
            distanceKm: 2.45,
            steps: 2890,
            syncedToHealth: true
        )

        SessionRow(
            date: Date().addingTimeInterval(-86400),
            durationSeconds: 900,
            distanceKm: 1.12,
            steps: 1340,
            syncedToHealth: false
        )
    }
}
