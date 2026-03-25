import SwiftUI

/// Control for adjusting WalkingPad speed with increment/decrement buttons.
/// Speed range: 0.5 - 6.0 km/h in 0.1 km/h steps.
struct SpeedControl: View {
    @Binding var currentSpeed: Double
    let isEnabled: Bool
    let onSpeedChange: (Double) -> Void

    // MARK: - Constants

    private let minSpeed: Double = 0.5
    private let maxSpeed: Double = 6.0
    private let speedStep: Double = 0.1

    var body: some View {
        VStack(spacing: Theme.spacing.sm) {
            Text("Speed")
                .font(Theme.typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)

            HStack(spacing: Theme.spacing.lg) {
                // Decrement button
                Button {
                    adjustSpeed(by: -speedStep)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(canDecrement ? ColorTokens.accent : ColorTokens.disabled)
                }
                .disabled(!canDecrement || !isEnabled)

                // Speed display
                VStack(spacing: Theme.spacing.xxs) {
                    Text(formattedSpeed)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(isEnabled ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                        .monospacedDigit()

                    Text("km/h")
                        .font(Theme.typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .frame(minWidth: 120)

                // Increment button
                Button {
                    adjustSpeed(by: speedStep)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(canIncrement ? ColorTokens.accent : ColorTokens.disabled)
                }
                .disabled(!canIncrement || !isEnabled)
            }
        }
        .padding(Theme.spacing.lg)
        .cardStyle()
    }

    // MARK: - Computed Properties

    private var formattedSpeed: String {
        String(format: "%.1f", currentSpeed)
    }

    private var canDecrement: Bool {
        currentSpeed > minSpeed
    }

    private var canIncrement: Bool {
        currentSpeed < maxSpeed
    }

    // MARK: - Actions

    private func adjustSpeed(by delta: Double) {
        let newSpeed = (currentSpeed + delta).clamped(to: minSpeed...maxSpeed)
        // Round to avoid floating point issues
        let roundedSpeed = (newSpeed * 10).rounded() / 10
        currentSpeed = roundedSpeed
        onSpeedChange(roundedSpeed)
    }
}

// MARK: - Comparable Extension

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

#Preview("Enabled") {
    SpeedControl(
        currentSpeed: .constant(3.0),
        isEnabled: true,
        onSpeedChange: { _ in }
    )
    .padding()
}

#Preview("Disabled") {
    SpeedControl(
        currentSpeed: .constant(2.5),
        isEnabled: false,
        onSpeedChange: { _ in }
    )
    .padding()
}

#Preview("At Min Speed") {
    SpeedControl(
        currentSpeed: .constant(0.5),
        isEnabled: true,
        onSpeedChange: { _ in }
    )
    .padding()
}

#Preview("At Max Speed") {
    SpeedControl(
        currentSpeed: .constant(6.0),
        isEnabled: true,
        onSpeedChange: { _ in }
    )
    .padding()
}
