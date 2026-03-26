import Foundation
import HealthKit
import CoreData

/// Handles HealthKit authorization and workout writes for walking sessions.
/// Saves completed walking sessions as HKWorkout records in Apple Health.
@Observable
final class HealthKitService {
    static let shared = HealthKitService()

    // MARK: - Published State

    /// Whether HealthKit authorization has been granted for writing workouts
    private(set) var isAuthorized = false

    /// Whether HealthKit is available on this device
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Last error encountered during HealthKit operations
    private(set) var lastError: HealthKitError?

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private let persistence = PersistenceController.shared

    /// Types we need to write to HealthKit
    private var typesToWrite: Set<HKSampleType> {
        guard let workoutType = HKObjectType.workoutType() as? HKSampleType else {
            return []
        }
        return [workoutType]
    }

    /// Types we need to read from HealthKit (for duplicate checking)
    private var typesToRead: Set<HKObjectType> {
        [HKObjectType.workoutType()]
    }

    // MARK: - Errors

    enum HealthKitError: Error, LocalizedError {
        case notAvailable
        case authorizationDenied
        case authorizationNotDetermined
        case saveFailed(String)
        case invalidSession

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "HealthKit is not available on this device."
            case .authorizationDenied:
                return "HealthKit access was denied. Enable it in Settings > Privacy > Health."
            case .authorizationNotDetermined:
                return "HealthKit authorization has not been requested yet."
            case .saveFailed(let message):
                return "Failed to save workout: \(message)"
            case .invalidSession:
                return "Session data is invalid or incomplete."
            }
        }
    }

    // MARK: - Public API

    /// Requests HealthKit authorization for writing workouts.
    /// - Returns: `true` if authorization was granted, `false` otherwise
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable else {
            lastError = .notAvailable
            return false
        }

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)

            // Check if we can actually write workouts
            let workoutType = HKObjectType.workoutType()
            let status = healthStore.authorizationStatus(for: workoutType)

            switch status {
            case .sharingAuthorized:
                isAuthorized = true
                lastError = nil
                return true
            case .sharingDenied:
                isAuthorized = false
                lastError = .authorizationDenied
                return false
            case .notDetermined:
                // User dismissed the dialog without making a choice
                isAuthorized = false
                lastError = .authorizationNotDetermined
                return false
            @unknown default:
                isAuthorized = false
                return false
            }
        } catch {
            lastError = .saveFailed(error.localizedDescription)
            isAuthorized = false
            return false
        }
    }

    /// Saves a completed walking session to HealthKit as an HKWorkout.
    /// - Parameter session: The WalkingSession to save
    /// - Returns: `true` if the workout was saved successfully
    @discardableResult
    func saveWalkingSession(_ session: WalkingSession) async -> Bool {
        guard isAvailable else {
            lastError = .notAvailable
            return false
        }

        // Ensure we have authorization
        if !isAuthorized {
            let authorized = await requestAuthorization()
            if !authorized { return false }
        }

        // Validate session data
        guard let startTime = session.startTime,
              let endTime = session.endTime else {
            lastError = .invalidSession
            return false
        }

        // Create the workout
        let workout = HKWorkout(
            activityType: .walking,
            start: startTime,
            end: endTime,
            duration: TimeInterval(session.durationSeconds),
            totalEnergyBurned: nil, // Not tracking calories in MVP
            totalDistance: HKQuantity(
                unit: .meterUnit(with: .kilo),
                doubleValue: session.distanceKm
            ),
            metadata: [
                HKMetadataKeyWasUserEntered: false,
                "WalkingPadSessionID": session.id?.uuidString ?? ""
            ]
        )

        do {
            try await healthStore.save(workout)

            // Mark session as synced
            await MainActor.run {
                session.syncedToHealth = true
                persistence.save()
            }

            lastError = nil
            return true
        } catch {
            lastError = .saveFailed(error.localizedDescription)
            return false
        }
    }

    /// Syncs any unsynced sessions to HealthKit.
    /// Useful for retrying failed syncs.
    func syncUnsyncedSessions() async {
        let context = persistence.viewContext
        let fetchRequest = WalkingSession.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "syncedToHealth == NO AND endTime != nil")

        do {
            let unsyncedSessions = try context.fetch(fetchRequest)
            for session in unsyncedSessions {
                await saveWalkingSession(session)
            }
        } catch {
            print("Failed to fetch unsynced sessions: \(error)")
        }
    }

    /// Checks current authorization status without prompting the user.
    func checkAuthorizationStatus() {
        guard isAvailable else {
            isAuthorized = false
            return
        }

        let workoutType = HKObjectType.workoutType()
        let status = healthStore.authorizationStatus(for: workoutType)
        isAuthorized = (status == .sharingAuthorized)
    }

    // MARK: - Initialization

    private init() {
        // Check initial authorization status
        checkAuthorizationStatus()
    }
}
