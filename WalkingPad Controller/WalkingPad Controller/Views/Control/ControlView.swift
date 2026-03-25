import SwiftUI

/// Main control screen for the WalkingPad.
/// Displays connection status, metrics, speed control, and start/stop button.
struct ControlView: View {
    @State private var walkingPadService = WalkingPadService.shared
    @State private var targetSpeed: Double = 3.0
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing.lg) {
                    // Connection status
                    ConnectionBanner(connectionState: walkingPadService.connectionState)

                    // Metrics display
                    if let status = walkingPadService.lastStatus {
                        MetricsCard(
                            elapsedSeconds: status.time,
                            distanceKm: status.distance,
                            steps: status.steps,
                            currentSpeedKmh: status.speed
                        )
                    } else {
                        MetricsCard(
                            elapsedSeconds: 0,
                            distanceKm: 0.0,
                            steps: 0,
                            currentSpeedKmh: 0.0
                        )
                    }

                    // Speed control
                    SpeedControl(
                        currentSpeed: $targetSpeed,
                        isEnabled: canControlPad,
                        onSpeedChange: handleSpeedChange
                    )

                    // Start/Stop button
                    startStopButton

                    Spacer(minLength: Theme.spacing.xl)
                }
                .padding(Theme.spacing.md)
            }
            .navigationTitle("Control")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await walkingPadService.checkConnection()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                await walkingPadService.checkConnection()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Start/Stop Button

    @ViewBuilder
    private var startStopButton: some View {
        let isRunning = walkingPadService.lastStatus?.padState.isActive ?? false

        Button {
            Task {
                await togglePad(isRunning: isRunning)
            }
        } label: {
            HStack(spacing: Theme.spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: isRunning ? "stop.fill" : "play.fill")
                }

                Text(isRunning ? "Stop" : "Start")
                    .font(.system(size: 20, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(.white)
            .background(buttonBackgroundColor(isRunning: isRunning))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius.md))
        }
        .disabled(!canControlPad || isLoading)
    }

    // MARK: - Computed Properties

    private var canControlPad: Bool {
        walkingPadService.connectionState.isConnected
    }

    private func buttonBackgroundColor(isRunning: Bool) -> Color {
        guard canControlPad else {
            return ColorTokens.disabled
        }
        return isRunning ? ColorTokens.error : ColorTokens.success
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

    private func togglePad(isRunning: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            if isRunning {
                try await walkingPadService.stop()
            } else {
                try await walkingPadService.start()
                // Set the target speed after starting
                try await walkingPadService.setSpeed(targetSpeed)
            }
            // Refresh status after action
            _ = try await walkingPadService.fetchStatus()
        } catch let error as BridgeAPIError {
            showError(error.errorDescription ?? "Operation failed")
        } catch {
            showError(error.localizedDescription)
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
