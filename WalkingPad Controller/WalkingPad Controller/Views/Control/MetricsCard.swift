import SwiftUI

/// Card displaying live session metrics: elapsed time, distance, steps, and current speed.
struct MetricsCard: View {
    let elapsedSeconds: Int
    let distanceKm: Double
    let steps: Int
    let currentSpeedKmh: Double

    var body: some View {
        VStack(spacing: Theme.spacing.md) {
            // Primary metric: Time
            VStack(spacing: Theme.spacing.xxs) {
                Text(formattedTime)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Duration")
                    .font(Theme.typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Divider()
                .padding(.horizontal, Theme.spacing.lg)

            // Secondary metrics grid
            HStack(spacing: Theme.spacing.xl) {
                MetricItem(
                    value: formattedDistance,
                    unit: "km",
                    label: "Distance"
                )

                MetricItem(
                    value: formattedSteps,
                    unit: nil,
                    label: "Steps"
                )

                MetricItem(
                    value: formattedSpeed,
                    unit: "km/h",
                    label: "Speed"
                )
            }
        }
        .padding(Theme.spacing.lg)
        .cardStyle()
    }

    // MARK: - Formatted Values

    private var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var formattedDistance: String {
        String(format: "%.2f", distanceKm)
    }

    private var formattedSteps: String {
        "\(steps)"
    }

    private var formattedSpeed: String {
        String(format: "%.1f", currentSpeedKmh)
    }
}

// MARK: - Metric Item

private struct MetricItem: View {
    let value: String
    let unit: String?
    let label: String

    var body: some View {
        VStack(spacing: Theme.spacing.xxs) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.textPrimary)

                if let unit {
                    Text(unit)
                        .font(Theme.typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }

            Text(label)
                .font(Theme.typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Default") {
    MetricsCard(
        elapsedSeconds: 754,
        distanceKm: 0.79,
        steps: 977,
        currentSpeedKmh: 3.5
    )
    .padding()
}

#Preview("Zero Values") {
    MetricsCard(
        elapsedSeconds: 0,
        distanceKm: 0.0,
        steps: 0,
        currentSpeedKmh: 0.0
    )
    .padding()
}

#Preview("Long Session") {
    MetricsCard(
        elapsedSeconds: 3661,
        distanceKm: 5.23,
        steps: 6542,
        currentSpeedKmh: 4.2
    )
    .padding()
}
