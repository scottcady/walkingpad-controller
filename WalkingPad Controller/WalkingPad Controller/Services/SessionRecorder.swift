import Foundation
import CoreData

/// Manages active walking session lifecycle: polling, Core Data persistence.
/// Handles starting/stopping sessions and maintaining live metrics during recording.
@Observable
final class SessionRecorder {
    static let shared = SessionRecorder()

    // MARK: - Published State

    /// Whether a session is currently being recorded
    private(set) var isRecording = false

    /// Live metrics updated during polling
    private(set) var liveMetrics: LiveMetrics?

    /// The current session being recorded (nil when not recording)
    private(set) var currentSession: WalkingSession?

    /// Last polling error (cleared on successful poll)
    private(set) var lastPollingError: BridgeAPIError?

    // MARK: - Live Metrics

    /// Real-time metrics displayed during an active session
    struct LiveMetrics: Equatable {
        let elapsedSeconds: Int
        let distanceKm: Double
        let steps: Int
        let currentSpeedKmh: Double
        let padState: PadState

        /// Formatted elapsed time as MM:SS
        var formattedTime: String {
            let minutes = elapsedSeconds / 60
            let seconds = elapsedSeconds % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }

        /// Formatted distance with 2 decimal places
        var formattedDistance: String {
            String(format: "%.2f", distanceKm)
        }
    }

    // MARK: - Private State

    private let walkingPadService = WalkingPadService.shared
    private let persistence = PersistenceController.shared

    /// Baseline values captured at session start (pad counters are cumulative)
    private var baselineTime: Int = 0
    private var baselineDistance: Double = 0.0
    private var baselineSteps: Int = 0

    /// Polling task reference for cancellation
    private var pollingTask: Task<Void, Never>?

    /// Polling interval in seconds
    private let pollingInterval: TimeInterval = 1.0

    /// Consecutive polling errors before showing error to user
    private let maxConsecutiveErrors = 3
    private var consecutiveErrors = 0

    // MARK: - Public API

    /// Starts recording a new walking session.
    /// Creates a Core Data entity and begins polling for status updates.
    func startRecording() {
        guard !isRecording else { return }

        // Create the session entity
        let context = persistence.viewContext
        let session = WalkingSession(context: context)
        session.id = UUID()
        session.startTime = Date()
        session.durationSeconds = 0
        session.distanceKm = 0.0
        session.steps = 0
        session.averageSpeedKmh = 0.0
        session.syncedToHealth = false

        // Save initial session
        persistence.save()

        currentSession = session
        isRecording = true
        lastPollingError = nil
        consecutiveErrors = 0

        // Capture baseline from current pad status
        if let status = walkingPadService.lastStatus {
            baselineTime = status.time
            baselineDistance = status.distance
            baselineSteps = status.steps
        } else {
            baselineTime = 0
            baselineDistance = 0.0
            baselineSteps = 0
        }

        // Initialize live metrics
        liveMetrics = LiveMetrics(
            elapsedSeconds: 0,
            distanceKm: 0.0,
            steps: 0,
            currentSpeedKmh: 0.0,
            padState: .idle
        )

        // Start polling
        startPolling()
    }

    /// Stops the current recording session.
    /// Finalizes the Core Data entity with final metrics.
    /// - Returns: The completed session, or nil if no session was recording
    @discardableResult
    func stopRecording() async -> WalkingSession? {
        guard isRecording, let session = currentSession else { return nil }

        // Stop polling first
        stopPolling()

        // Fetch final status
        do {
            let finalStatus = try await walkingPadService.fetchStatus()
            updateMetrics(from: finalStatus)
        } catch {
            // Use last known metrics if final fetch fails
        }

        // Finalize the session
        finalizeSession(session)

        // Reset state
        isRecording = false
        currentSession = nil

        return session
    }

    /// Discards the current session without saving.
    func discardSession() {
        guard isRecording, let session = currentSession else { return }

        stopPolling()

        // Delete the session from Core Data
        let context = persistence.viewContext
        context.delete(session)
        persistence.save()

        // Reset state
        isRecording = false
        currentSession = nil
        liveMetrics = nil
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: .seconds(self?.pollingInterval ?? 1.0))
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func poll() async {
        do {
            let status = try await walkingPadService.fetchStatus()
            await MainActor.run {
                self.updateMetrics(from: status)
                self.consecutiveErrors = 0
                self.lastPollingError = nil
            }
        } catch let error as BridgeAPIError {
            await MainActor.run {
                self.consecutiveErrors += 1
                if self.consecutiveErrors >= self.maxConsecutiveErrors {
                    self.lastPollingError = error
                }
            }
        } catch {
            await MainActor.run {
                self.consecutiveErrors += 1
                if self.consecutiveErrors >= self.maxConsecutiveErrors {
                    self.lastPollingError = .unknown(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Metrics Update

    private func updateMetrics(from status: BridgeStatus) {
        // Calculate deltas from baseline
        let elapsedSeconds = max(0, status.time - baselineTime)
        let distanceKm = max(0, status.distance - baselineDistance)
        let steps = max(0, status.steps - baselineSteps)

        liveMetrics = LiveMetrics(
            elapsedSeconds: elapsedSeconds,
            distanceKm: distanceKm,
            steps: steps,
            currentSpeedKmh: status.speed,
            padState: status.padState
        )

        // Update session entity periodically (for crash recovery)
        if let session = currentSession {
            session.durationSeconds = Int32(elapsedSeconds)
            session.distanceKm = distanceKm
            session.steps = Int32(steps)

            // Calculate average speed
            if elapsedSeconds > 0 {
                let hours = Double(elapsedSeconds) / 3600.0
                session.averageSpeedKmh = distanceKm / hours
            }
        }
    }

    // MARK: - Session Finalization

    private func finalizeSession(_ session: WalkingSession) {
        guard let metrics = liveMetrics else { return }

        session.endTime = Date()
        session.durationSeconds = Int32(metrics.elapsedSeconds)
        session.distanceKm = metrics.distanceKm
        session.steps = Int32(metrics.steps)

        // Calculate average speed: distance / (duration in hours)
        if metrics.elapsedSeconds > 0 {
            let hours = Double(metrics.elapsedSeconds) / 3600.0
            session.averageSpeedKmh = metrics.distanceKm / hours
        } else {
            session.averageSpeedKmh = 0.0
        }

        persistence.save()
    }

    // MARK: - Initialization

    private init() {}
}
