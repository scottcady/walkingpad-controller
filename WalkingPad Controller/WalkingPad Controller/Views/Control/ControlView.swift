import SwiftUI

/// Main control screen for the WalkingPad.
/// Minimal layout: timer, start/stop button, speed slider.
struct ControlView: View {
    @State private var walkingPadService = WalkingPadService.shared
    @State private var sessionRecorder = SessionRecorder.shared
    @State private var targetSpeed: Double = 3.0
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hapticTrigger = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let minSpeed: Double = 0.5
    private let maxSpeed: Double = 6.0

    var body: some View {
        VStack(spacing: 0) {
            // Connection indicator
            connectionIndicator
                .padding(.top, Theme.spacing.md)

            Spacer()

            // Timer display
            timerDisplay

            Spacer()

            // Start/Stop button
            startStopButton
                .padding(.bottom, Theme.spacing.xl)

            // Speed slider
            speedSlider
                .padding(.horizontal, Theme.spacing.xl)
                .padding(.bottom, Theme.spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.surface)
        .task {
            await walkingPadService.checkConnection()
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
                        await walkingPadService.checkConnection()
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
        switch walkingPadService.connectionState {
        case .connected:
            return ColorTokens.success
        case .connecting:
            return ColorTokens.warning
        case .disconnected, .error:
            return ColorTokens.error
        }
    }

    private var connectionText: String {
        switch walkingPadService.connectionState {
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
        } else if let status = walkingPadService.lastStatus {
            seconds = status.time
        } else {
            seconds = 0
        }

        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
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

    // MARK: - Speed Slider

    @ViewBuilder
    private var speedSlider: some View {
        VStack(spacing: Theme.spacing.sm) {
            HStack {
                Text("Speed")
                    .font(Theme.typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)

                Spacer()

                Text(String(format: "%.1f km/h", targetSpeed))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(canControlPad ? ColorTokens.textPrimary : ColorTokens.textSecondary)
            }

            Slider(value: $targetSpeed, in: minSpeed...maxSpeed, step: 0.5) { editing in
                if !editing {
                    handleSpeedChange(targetSpeed)
                }
            }
            .tint(ColorTokens.accent)
            .disabled(!canControlPad)

            HStack {
                Text(String(format: "%.1f", minSpeed))
                    .font(Theme.typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)

                Spacer()

                Text(String(format: "%.1f", maxSpeed))
                    .font(Theme.typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .padding(Theme.spacing.lg)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius.md))
    }

    // MARK: - Computed Properties

    private var canControlPad: Bool {
        walkingPadService.connectionState.isConnected
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
                try await walkingPadService.setSpeed(newSpeed)
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
                try await walkingPadService.stop()
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
                try await walkingPadService.start()
                try await walkingPadService.setSpeed(targetSpeed)
                _ = try await walkingPadService.fetchStatus()
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
