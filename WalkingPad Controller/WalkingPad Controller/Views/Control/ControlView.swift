import SwiftUI

/// Main control screen for the WalkingPad.
/// Displays connection status, metrics, speed control, and start/stop button.
struct ControlView: View {
    @State private var walkingPadService = WalkingPadService.shared
    @State private var sessionRecorder = SessionRecorder.shared
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

                    // Polling error banner (only during recording)
                    if sessionRecorder.isRecording, let pollingError = sessionRecorder.lastPollingError {
                        pollingErrorBanner(error: pollingError)
                    }

                    // Metrics display - show live metrics when recording, otherwise pad status
                    if sessionRecorder.isRecording, let metrics = sessionRecorder.liveMetrics {
                        MetricsCard(
                            elapsedSeconds: metrics.elapsedSeconds,
                            distanceKm: metrics.distanceKm,
                            steps: metrics.steps,
                            currentSpeedKmh: metrics.currentSpeedKmh
                        )
                    } else if let status = walkingPadService.lastStatus {
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
                    .disabled(isLoading || sessionRecorder.isRecording)
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

    // MARK: - Polling Error Banner

    @ViewBuilder
    private func pollingErrorBanner(error: BridgeAPIError) -> some View {
        HStack(spacing: Theme.spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTokens.warning)

            Text("Connection unstable: \(error.errorDescription ?? "Unknown error")")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textSecondary)

            Spacer()
        }
        .padding(Theme.spacing.sm)
        .background(ColorTokens.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius.sm))
    }

    // MARK: - Start/Stop Button

    @ViewBuilder
    private var startStopButton: some View {
        let isRecording = sessionRecorder.isRecording

        Button {
            Task {
                await toggleSession()
            }
        } label: {
            HStack(spacing: Theme.spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: isRecording ? "stop.fill" : "play.fill")
                }

                Text(isRecording ? "Stop" : "Start")
                    .font(.system(size: 20, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(.white)
            .background(buttonBackgroundColor(isRecording: isRecording))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius.md))
        }
        .disabled(!canControlPad || isLoading)
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
            // Stop the session
            do {
                try await walkingPadService.stop()
            } catch let error as BridgeAPIError {
                showError(error.errorDescription ?? "Failed to stop pad")
                return
            } catch {
                showError(error.localizedDescription)
                return
            }

            // Stop recording (finalizes session to Core Data)
            _ = await sessionRecorder.stopRecording()

        } else {
            // Start a new session
            do {
                try await walkingPadService.start()
                try await walkingPadService.setSpeed(targetSpeed)
                // Fetch initial status for baseline
                _ = try await walkingPadService.fetchStatus()
            } catch let error as BridgeAPIError {
                showError(error.errorDescription ?? "Failed to start pad")
                return
            } catch {
                showError(error.localizedDescription)
                return
            }

            // Start recording
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
