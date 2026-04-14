import SwiftUI

/// Main control screen for the WalkingPad.
/// Minimal layout: timer, start/stop button, speed control.
struct ControlView: View {
    @State private var connectionManager = ConnectionManager.shared
    @State private var sessionRecorder = SessionRecorder.shared
    @State private var targetSpeed: Double = 2.5
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hapticTrigger = false
    @State private var speedHapticTrigger = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let minSpeed: Double = 0.5
    private let maxSpeed: Double = 4.0
    private let speedStep: Double = 0.5

    var body: some View {
        ZStack {
            ColorTokens.surface
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Connection indicator
                connectionIndicator
                    .padding(.top, Theme.spacing.md)

                Spacer()

                // Timer display
                timerDisplay

                // Distance and steps
                metricsDisplay
                    .padding(.top, Theme.spacing.lg)

                Spacer()

                // Start/Stop button
                startStopButton

                Spacer()

                // Speed control
                speedControl
                    .padding(.horizontal, Theme.spacing.xl)
                    .padding(.bottom, Theme.spacing.md)
            }
        }
        .task {
            await connectionManager.checkConnection()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Connection Indicator

    @ViewBuilder
    private var connectionIndicator: some View {
        HStack(spacing: Theme.spacing.sm) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)

            Text(connectionText)
                .font(Theme.typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)

            Spacer()

            if !sessionRecorder.isRecording {
                Button {
                    Task {
                        await connectionManager.checkConnection()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
        .padding(.horizontal, Theme.spacing.lg)
    }

    private var connectionColor: Color {
        switch connectionManager.connectionState {
        case .connected:
            return ColorTokens.success
        case .connecting:
            return ColorTokens.warning
        case .disconnected, .error:
            return ColorTokens.error
        }
    }

    private var connectionText: String {
        switch connectionManager.connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .error(let message):
            return message
        }
    }

    // MARK: - Timer Display

    @ViewBuilder
    private var timerDisplay: some View {
        VStack(spacing: Theme.spacing.xs) {
            Text(formattedTime)
                .font(.system(size: 72, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ColorTokens.textPrimary)

            if sessionRecorder.isRecording {
                Text("Recording")
                    .font(Theme.typography.caption)
                    .foregroundStyle(ColorTokens.success)
            }
        }
    }

    private var formattedTime: String {
        let seconds: Int
        if sessionRecorder.isRecording, let metrics = sessionRecorder.liveMetrics {
            seconds = metrics.elapsedSeconds
        } else if let status = connectionManager.lastStatus {
            seconds = status.time
        } else {
            seconds = 0
        }

        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Metrics Display

    @ViewBuilder
    private var metricsDisplay: some View {
        HStack(spacing: Theme.spacing.xl) {
            // Distance
            VStack(spacing: Theme.spacing.xxs) {
                Text(formattedDistance)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("km")
                    .font(Theme.typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .frame(minWidth: 80)

            // Divider
            Rectangle()
                .fill(ColorTokens.textTertiary.opacity(0.3))
                .frame(width: 1, height: 40)

            // Steps
            VStack(spacing: Theme.spacing.xxs) {
                Text(formattedSteps)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("steps")
                    .font(Theme.typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .frame(minWidth: 80)
        }
        .padding(.horizontal, Theme.spacing.lg)
        .padding(.vertical, Theme.spacing.md)
        .background(ColorTokens.surfaceElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius.md))
    }

    private var formattedDistance: String {
        let distance: Double
        if sessionRecorder.isRecording, let metrics = sessionRecorder.liveMetrics {
            distance = metrics.distanceKm
        } else if let status = connectionManager.lastStatus {
            distance = status.distance
        } else {
            distance = 0.0
        }
        return String(format: "%.2f", distance)
    }

    private var formattedSteps: String {
        let steps: Int
        if sessionRecorder.isRecording, let metrics = sessionRecorder.liveMetrics {
            steps = metrics.steps
        } else if let status = connectionManager.lastStatus {
            steps = status.steps
        } else {
            steps = 0
        }
        return "\(steps)"
    }

    // MARK: - Start/Stop Button

    @ViewBuilder
    private var startStopButton: some View {
        let isRecording = sessionRecorder.isRecording
        let buttonSize: CGFloat = 140

        Button {
            hapticTrigger.toggle()
            Task {
                await toggleSession()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(buttonBackgroundColor(isRecording: isRecording))
                    .frame(width: buttonSize, height: buttonSize)
                    .shadow(color: buttonBackgroundColor(isRecording: isRecording).opacity(0.4),
                            radius: 12, x: 0, y: 6)

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else {
                    Image(systemName: isRecording ? "stop.fill" : "play.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(.white)
                        .offset(x: isRecording ? 0 : 4)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
        .disabled(!canControlPad || isLoading)
    }

    // MARK: - Speed Control

    @ViewBuilder
    private var speedControl: some View {
        HStack(spacing: Theme.spacing.lg) {
            // Decrease speed button
            Button {
                decreaseSpeed()
            } label: {
                Text("−")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(canDecreaseSpeed ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                    .frame(width: 72, height: 72)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius.md))
            }
            .disabled(!canDecreaseSpeed)
            .sensoryFeedback(.impact(weight: .medium), trigger: speedHapticTrigger)

            // Speed display
            VStack(spacing: Theme.spacing.xs) {
                Text(String(format: "%.1f", targetSpeed))
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(canControlPad ? ColorTokens.textPrimary : ColorTokens.textSecondary)

                Text("km/h")
                    .font(Theme.typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .frame(minWidth: 100)

            // Increase speed button
            Button {
                increaseSpeed()
            } label: {
                Text("+")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(canIncreaseSpeed ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                    .frame(width: 72, height: 72)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius.md))
            }
            .disabled(!canIncreaseSpeed)
            .sensoryFeedback(.impact(weight: .medium), trigger: speedHapticTrigger)
        }
        .padding(Theme.spacing.lg)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius.md))
    }

    private var canDecreaseSpeed: Bool {
        canControlPad && targetSpeed > minSpeed
    }

    private var canIncreaseSpeed: Bool {
        canControlPad && targetSpeed < maxSpeed
    }

    private func decreaseSpeed() {
        guard canDecreaseSpeed else { return }
        speedHapticTrigger.toggle()
        let newSpeed = max(minSpeed, targetSpeed - speedStep)
        targetSpeed = newSpeed
        handleSpeedChange(newSpeed)
    }

    private func increaseSpeed() {
        guard canIncreaseSpeed else { return }
        speedHapticTrigger.toggle()
        let newSpeed = min(maxSpeed, targetSpeed + speedStep)
        targetSpeed = newSpeed
        handleSpeedChange(newSpeed)
    }

    // MARK: - Computed Properties

    private var canControlPad: Bool {
        connectionManager.connectionState.isConnected
    }

    private func buttonBackgroundColor(isRecording: Bool) -> Color {
        guard canControlPad else {
            return ColorTokens.disabled
        }
        return isRecording ? ColorTokens.error : ColorTokens.success
    }

    // MARK: - Actions

    private func handleSpeedChange(_ newSpeed: Double) {
        guard canControlPad else { return }

        Task {
            do {
                try await connectionManager.setSpeed(newSpeed)
            } catch let error as BridgeAPIError {
                showError(error.errorDescription ?? "Failed to set speed")
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private func toggleSession() async {
        isLoading = true
        defer { isLoading = false }

        if sessionRecorder.isRecording {
            do {
                try await connectionManager.stop()
            } catch let error as BridgeAPIError {
                showError(error.errorDescription ?? "Failed to stop pad")
                return
            } catch {
                showError(error.localizedDescription)
                return
            }

            _ = await sessionRecorder.stopRecording()

        } else {
            do {
                try await connectionManager.start()
                try await connectionManager.setSpeed(targetSpeed)
                _ = try await connectionManager.fetchStatus()
            } catch let error as BridgeAPIError {
                showError(error.errorDescription ?? "Failed to start pad")
                return
            } catch {
                showError(error.localizedDescription)
                return
            }

            sessionRecorder.startRecording()
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

#Preview {
    ControlView()
}
