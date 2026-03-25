# WalkingPad Controller — Implementation Plan

> Standalone iOS app to control a WalkingPad A1 Pro treadmill via a Mac-hosted FastAPI bridge.
> Built for lift-and-place compatibility with Compound Fitness app.

---

## Progress Tracking Instructions

**For Claude Code sessions:** Update this document in real time as you complete implementation steps. Mark checkboxes with `[x]` immediately after completing each task. This ensures continuity across sessions and provides clear visibility into project status.

---

## Table of Contents

1. [Overview](#overview)
2. [Tech Stack](#tech-stack)
3. [Architecture](#architecture)
4. [Project Structure](#project-structure)
5. [Core Data Schema](#core-data-schema)
6. [Bridge API Contract](#bridge-api-contract)
7. [Service Designs](#service-designs)
8. [Entitlements & Info.plist](#entitlements--infoplist)
9. [Implementation Phases](#implementation-phases)
10. [Lift-and-Place Assessment](#lift-and-place-assessment)
11. [Open Questions & Future Work](#open-questions--future-work)

---

## Overview

### What This App Does

- Connects to a WalkingPad A1 Pro treadmill via a local network bridge
- Provides start/stop control and speed adjustment (0.5–6.0 km/h)
- Displays live metrics: elapsed time, distance, steps, current speed
- Records walking sessions to Core Data
- Writes completed sessions to Apple Health as walking workouts

### Hardware Context

- **WalkingPad A1 Pro**: Communicates over Bluetooth LE
- **Bridge Service**: Mac-hosted FastAPI server using [ph4-walkingpad](https://github.com/ph4r05/ph4-walkingpad) Python library
- **Connection Model**: iOS app → WiFi → Bridge (REST API) → BLE → WalkingPad
- **Constraint**: Only one BLE connection allowed; bridge owns it exclusively

### Key Behavioral Requirements

1. **No silent failures** — Clear error states when bridge is unreachable
2. **Immediate persistence** — Poll actively during session; persist to Core Data on stop (pad stats don't survive power cuts)
3. **Local network only** — No internet connectivity assumed for pad control

---

## Tech Stack

Matches Compound Fitness exactly for lift-and-place compatibility:

| Layer | Technology |
|-------|------------|
| UI | SwiftUI |
| State Management | `@Observable` (iOS 17+) |
| Persistence | Core Data |
| Cloud Sync | CloudKit-ready (disabled for MVP) |
| Health | HealthKit |
| Networking | URLSession (no third-party deps) |
| Design System | Lifted from Compound Fitness |

---

## Architecture

### Service-Based Architecture

```
┌─────────────────────────────────────────────────────────┐
│                        Views                             │
│  ControlView  │  HistoryView  │  SettingsView           │
└───────┬───────────────┬───────────────┬─────────────────┘
        │               │               │
        ▼               ▼               ▼
┌─────────────────────────────────────────────────────────┐
│                      Services                            │
│  WalkingPadService  │  SessionRecorder  │  HealthKit    │
│  SettingsService    │                                    │
└───────┬───────────────┬───────────────┬─────────────────┘
        │               │               │
        ▼               ▼               ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ REST Bridge │  │  Core Data  │  │  HealthKit  │
│  (FastAPI)  │  │             │  │    Store    │
└─────────────┘  └─────────────┘  └─────────────┘
```

### Data Flow During Session

```
1. User taps START
2. WalkingPadService.start() → POST /start to bridge
3. SessionRecorder creates WalkingSession entity (startTime = now)
4. SessionRecorder starts 1-second polling loop:
   └─► WalkingPadService.fetchStatus() → GET /status
   └─► Update liveMetrics for UI
5. User taps STOP
6. WalkingPadService.stop() → POST /stop to bridge
7. SessionRecorder fetches final status
8. SessionRecorder finalizes WalkingSession (endTime, duration, distance, steps)
9. HealthKitService.saveWalkingSession() → HKWorkout
```

---

## Project Structure

```
WalkingPad Controller/
├── WalkingPad Controller/
│   ├── App/
│   │   └── WalkingPadControllerApp.swift      # App entry point
│   │
│   ├── Persistence/
│   │   ├── Persistence.swift                  # Core Data stack
│   │   └── WalkingPadController.xcdatamodeld/ # Data model
│   │
│   ├── Models/
│   │   ├── BridgeStatus.swift                 # GET /status response
│   │   ├── PadState.swift                     # Belt state enum
│   │   └── BridgeAPIError.swift               # Error types
│   │
│   ├── Services/
│   │   ├── WalkingPadService.swift            # Bridge communication
│   │   ├── SessionRecorder.swift              # Polling + persistence
│   │   ├── HealthKitService.swift             # HKWorkout writes
│   │   └── SettingsService.swift              # UserDefaults wrapper
│   │
│   ├── Views/
│   │   ├── MainTabView.swift                  # Tab container
│   │   ├── Control/
│   │   │   ├── ControlView.swift              # Main control screen
│   │   │   ├── MetricsCard.swift              # Live stats display
│   │   │   ├── SpeedControl.swift             # Speed +/- buttons
│   │   │   └── ConnectionBanner.swift         # Error states
│   │   ├── History/
│   │   │   ├── HistoryView.swift              # Session list
│   │   │   └── SessionRow.swift               # List row component
│   │   └── Settings/
│   │       └── SettingsView.swift             # Bridge URL config
│   │
│   ├── DesignSystem/                          # Lifted from Compound Fitness
│   │   ├── Theme.swift
│   │   ├── ColorTokens.swift
│   │   ├── SpacingTokens.swift
│   │   ├── TypographyTokens.swift
│   │   └── RadiusTokens.swift
│   │
│   └── Info.plist
│
├── WalkingPad Controller.entitlements
│
└── WalkingPad ControllerTests/
    ├── WalkingPadServiceTests.swift
    └── SessionRecorderTests.swift
```

---

## Core Data Schema

### Entity: WalkingSession

| Attribute | Type | Optional | Default | Notes |
|-----------|------|----------|---------|-------|
| `id` | UUID | No | `UUID()` | Primary identifier |
| `startTime` | Date | No | — | Session start timestamp |
| `endTime` | Date | Yes | `nil` | Null while session in progress |
| `durationSeconds` | Int32 | No | `0` | Total elapsed seconds |
| `distanceKm` | Double | No | `0.0` | Distance in kilometers |
| `steps` | Int32 | No | `0` | Total step count |
| `averageSpeedKmh` | Double | No | `0.0` | Computed: distance / (duration/3600) |
| `syncedToHealth` | Bool | No | `false` | True after HealthKit write succeeds |

### Core Data Configuration

```swift
// Persistence.swift
let container = NSPersistentContainer(name: "WalkingPadController")

// Enable history tracking for future CloudKit migration
let description = container.persistentStoreDescriptions.first
description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

// Merge policy
container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
container.viewContext.automaticallyMergesChangesFromParent = true
```

---

## Bridge API Contract

Based on [ph4-walkingpad](https://github.com/ph4r05/ph4-walkingpad) library.

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/status` | Current pad status |
| `POST` | `/start` | Start the belt |
| `POST` | `/stop` | Stop the belt |
| `POST` | `/speed/{value}` | Set speed (raw value: 5-60) |

### GET /status Response

```json
{
  "time": 554,
  "distance": 0.79,
  "steps": 977,
  "speed": 6.0,
  "state": 1,
  "mode": 1,
  "running": true
}
```

| Field | Type | Unit | Notes |
|-------|------|------|-------|
| `time` | int | seconds | Elapsed time since pad powered on |
| `distance` | float | km | Raw value ÷ 100 |
| `steps` | int | count | Direct value |
| `speed` | float | km/h | Raw value ÷ 10 |
| `state` | int | enum | 0=idle, 1=running, 5=standby, 9=starting |
| `mode` | int | enum | 0=auto, 1=manual, 2=standby |
| `running` | bool | — | Convenience: state == 1 |

### POST /speed/{value}

- `value` is raw integer: multiply km/h by 10
- Example: 3.5 km/h → `/speed/35`
- Valid range: 5 to 60 (0.5 to 6.0 km/h)

### Error Responses

```json
{
  "detail": "Not connected to WalkingPad"
}
```

| HTTP Status | Meaning |
|-------------|---------|
| 200 | Success |
| 400 | Bad request (validation error, not connected) |
| 404 | WalkingPad not found during scan |
| 500 | BLE communication failure |

---

## Service Designs

### WalkingPadService

Manages all bridge communication and connection state.

```swift
@Observable
final class WalkingPadService {
    static let shared = WalkingPadService()

    // Published state
    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var lastStatus: BridgeStatus?
    private(set) var lastError: BridgeAPIError?

    // Configuration
    private let session = URLSession.shared
    private let timeoutInterval: TimeInterval = 5.0

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    // MARK: - Public API

    func checkConnection() async
    func fetchStatus() async throws -> BridgeStatus
    func start() async throws
    func stop() async throws
    func setSpeed(_ kmh: Double) async throws  // 0.5 - 6.0
}
```

### SessionRecorder

Manages active session lifecycle: polling, Core Data persistence, HealthKit sync.

```swift
@Observable
final class SessionRecorder {
    static let shared = SessionRecorder()

    private(set) var isRecording = false
    private(set) var liveMetrics: LiveMetrics?

    struct LiveMetrics: Equatable {
        let elapsedSeconds: Int
        let distanceKm: Double
        let steps: Int
        let currentSpeedKmh: Double
        let padState: PadState
    }

    // MARK: - Public API

    func startRecording()           // Creates entity, starts polling
    func stopRecording() async      // Finalizes entity, writes to HealthKit
}
```

### HealthKitService

Handles HealthKit authorization and workout writes.

```swift
@Observable
final class HealthKitService {
    static let shared = HealthKitService()

    private(set) var isAuthorized = false

    // MARK: - Public API

    func requestAuthorization() async -> Bool
    func saveWalkingSession(_ session: WalkingSession) async
}
```

### SettingsService

Simple UserDefaults wrapper for bridge URL.

```swift
final class SettingsService {
    static let shared = SettingsService()

    private let defaults = UserDefaults.standard
    private let bridgeURLKey = "bridgeURL"

    var bridgeURL: String? {
        get { defaults.string(forKey: bridgeURLKey) }
        set { defaults.set(newValue, forKey: bridgeURLKey) }
    }
}
```

---

## Entitlements & Info.plist

### Entitlements File

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
</dict>
</plist>
```

### Info.plist Keys

```xml
<!-- HealthKit -->
<key>NSHealthShareUsageDescription</key>
<string>WalkingPad Controller reads health data to avoid duplicate workouts.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>WalkingPad Controller saves your walking sessions as workouts in Apple Health.</string>

<!-- Local Network Access -->
<key>NSLocalNetworkUsageDescription</key>
<string>WalkingPad Controller connects to your WalkingPad bridge on your local network.</string>

<key>NSBonjourServices</key>
<array>
    <string>_http._tcp</string>
</array>
```

### Xcode Capabilities

1. **HealthKit** — Enable in Signing & Capabilities
2. **Background Modes** — Not required (polling only while foregrounded)

---

## Implementation Phases

### Phase 1: Project Setup ✅
- [x] Create Xcode project (iOS App, SwiftUI, Swift)
- [x] Add HealthKit capability
- [x] Copy DesignSystem files from Compound Fitness
- [x] Create Core Data model (WalkingSession entity)
- [x] Create Persistence.swift with history tracking enabled
- [x] Create app entry point with environment setup

**Deliverable:** App builds and runs with empty UI, Core Data stack ready.

---

### Phase 2: Settings & Configuration ✅
- [x] Create SettingsService (UserDefaults wrapper)
- [x] Create SettingsView with bridge URL text field
- [x] Add URL validation (http:// prefix, port format)
- [x] Store/retrieve URL on app launch

**Deliverable:** User can configure and persist bridge URL.

---

### Phase 3: Bridge Communication ✅
- [x] Create BridgeStatus model (Codable)
- [x] Create PadState enum with display names
- [x] Create BridgeAPIError with user-friendly messages
- [x] Implement WalkingPadService:
  - [x] checkConnection()
  - [x] fetchStatus()
  - [x] start()
  - [x] stop()
  - [x] setSpeed()
- [x] Add timeout handling (5 seconds)
- [x] Add proper error mapping from HTTP responses

**Deliverable:** Can communicate with bridge, handle all error states.

---

### Phase 4: Control UI ✅
- [x] Create MainTabView (Control, History, Settings tabs)
- [x] Create ConnectionBanner component:
  - [x] Disconnected state
  - [x] Connecting state
  - [x] Error state with message
- [x] Create ControlView:
  - [x] Connection status at top
  - [x] Start/Stop button (state-aware)
  - [x] Disabled state when not connected
- [x] Create SpeedControl:
  - [x] Current speed display
  - [x] Increment/decrement buttons (0.1 km/h steps)
  - [x] Min/max bounds (0.5 - 6.0 km/h)
- [x] Create MetricsCard:
  - [x] Elapsed time (MM:SS format)
  - [x] Distance (X.XX km)
  - [x] Steps count
  - [x] Current speed

**Deliverable:** Full control UI with live feedback, proper error states.

---

### Phase 5: Session Recording ✅
- [x] Implement SessionRecorder:
  - [x] startRecording() — create Core Data entity, start polling
  - [x] Polling loop (1-second interval)
  - [x] Update liveMetrics on each poll
  - [x] stopRecording() — cancel polling, finalize entity
- [x] Handle polling errors gracefully (don't crash session)
- [x] Calculate averageSpeedKmh on finalization
- [x] Integrate with ControlView for live metrics display

**Deliverable:** Sessions recorded to Core Data with accurate metrics.

---

### Phase 6: HealthKit Integration
- [ ] Implement HealthKitService:
  - [ ] requestAuthorization()
  - [ ] saveWalkingSession()
- [ ] Request authorization on first session start
- [ ] Create HKWorkout with:
  - [ ] activityType: .walking
  - [ ] start/end dates
  - [ ] duration
  - [ ] totalDistance
- [ ] Mark session.syncedToHealth = true on success
- [ ] Handle authorization denied gracefully

**Deliverable:** Completed sessions appear in Apple Health.

---

### Phase 7: History
- [ ] Create HistoryView with @FetchRequest
- [ ] Sort by startTime descending
- [ ] Create SessionRow component:
  - [ ] Date/time
  - [ ] Duration
  - [ ] Distance
  - [ ] Steps
  - [ ] HealthKit sync indicator
- [ ] Empty state when no sessions
- [ ] Optional: swipe to delete

**Deliverable:** Users can view past sessions.

---

### Phase 8: Polish & Testing
- [ ] Add haptic feedback on start/stop
- [ ] Respect accessibilityReduceMotion
- [ ] Test on device with real bridge
- [ ] Test error scenarios:
  - [ ] Bridge unreachable
  - [ ] Bridge connected but pad disconnected
  - [ ] Mid-session connection loss
- [ ] Test HealthKit edge cases:
  - [ ] Authorization denied
  - [ ] Write failure
- [ ] Clean up any debug code

**Deliverable:** Production-ready MVP.

---

## Lift-and-Place Assessment

Evaluation of how cleanly each component can be moved to Compound Fitness:

| Component | Lifts Cleanly? | Notes |
|-----------|----------------|-------|
| **DesignSystem/** | Yes | Already generic, direct copy |
| **HealthKitService** | Yes | Parameterize activityType for other workout types |
| **SettingsService** | Yes | Standard UserDefaults pattern |
| **BridgeAPIError** | Yes | Generic error handling pattern |
| **WalkingPadService** | Mostly | Consider protocol abstraction for multiple device types |
| **SessionRecorder** | Mostly | Polling pattern is device-specific; may need abstraction |
| **WalkingSession entity** | Consider | May want to merge into main app's Session entity or keep separate |
| **Control UI** | Mostly | UI is purpose-built but follows same patterns |

### Recommendations for Future Integration

1. **Protocol for Device Services**: If adding other controllable devices, extract `DeviceService` protocol
2. **Unified Session Entity**: Consider whether WalkingSession should be a separate entity or a type of the main Session
3. **Shared HealthKitService**: Main app may need broader HealthKit types; design for extension

---

## Open Questions & Future Work

### Deferred to Post-MVP

- [ ] CloudKit sync (requires paid developer account)
- [ ] Background session support (requires Background Tasks + bridge push notifications)
- [ ] Multiple bridge support (switching between home/gym)
- [ ] Calorie estimation (requires user profile: weight, age, gender)
- [ ] Session notes/tags
- [ ] Workout history sync from HealthKit (read existing workouts)

### Bridge Enhancements (Separate Project)

- [ ] WebSocket support for real-time updates (lower latency than polling)
- [ ] Auto-reconnect on BLE disconnect
- [ ] Session persistence on bridge (survive iOS app backgrounding)

---

## References

- [ph4-walkingpad](https://github.com/ph4r05/ph4-walkingpad) — Python library for WalkingPad BLE
- [Compound Fitness App](../compound-fitness-app) — Reference for patterns and design system
- [Apple HealthKit Documentation](https://developer.apple.com/documentation/healthkit)
- [Core Data + CloudKit](https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit)
