import Foundation
import CoreBluetooth
import Observation

/// Direct Bluetooth Low Energy service for communicating with the WalkingPad.
/// Implements the PadConnectionService protocol using CoreBluetooth.
@Observable
final class BluetoothPadService: NSObject, PadConnectionService {
    static let shared = BluetoothPadService()

    // MARK: - BLE Constants

    private static let serviceUUID = CBUUID(string: "0000FE00-0000-1000-8000-00805F9B34FB")
    private static let readCharacteristicUUID = CBUUID(string: "0000FE01-0000-1000-8000-00805F9B34FB")
    private static let writeCharacteristicUUID = CBUUID(string: "0000FE02-0000-1000-8000-00805F9B34FB")

    // Device name patterns to scan for
    private static let deviceNamePatterns = ["WalkingPad", "KingSmith"]

    // Protocol constants
    private static let header: UInt8 = 0xF7
    private static let footer: UInt8 = 0xFD
    private static let statusHeader: UInt8 = 0xF8
    private static let commandPrefix: UInt8 = 0xA2

    // MARK: - Observable State

    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var lastStatus: BridgeStatus?
    private(set) var lastError: BridgeAPIError?

    // MARK: - Private Properties

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var readCharacteristic: CBCharacteristic?
    private var writeCharacteristic: CBCharacteristic?

    // Async continuation storage for pending operations
    private var scanContinuation: CheckedContinuation<CBPeripheral, Error>?
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var discoverContinuation: CheckedContinuation<Void, Error>?
    private var readContinuation: CheckedContinuation<Data, Error>?

    // Buffer for incoming BLE data
    private var responseBuffer = Data()

    // Timeout for operations
    private let operationTimeout: TimeInterval = 10.0

    // MARK: - Initialization

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Connection Management

    func checkConnection() async {
        // Check if we're already connected
        if let peripheral = peripheral, peripheral.state == .connected,
           readCharacteristic != nil, writeCharacteristic != nil {
            connectionState = .connected

            // Verify connection by requesting status
            do {
                _ = try await fetchStatus()
                connectionState = .connected
            } catch {
                connectionState = .error("Connection lost")
                lastError = .padNotConnected
            }
        } else {
            // Try to connect
            do {
                try await connect()
                connectionState = .connected
            } catch {
                connectionState = .disconnected
                if let bleError = error as? BridgeAPIError {
                    lastError = bleError
                } else {
                    lastError = .bleFailure
                }
            }
        }
    }

    func disconnect() async {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }

        peripheral = nil
        readCharacteristic = nil
        writeCharacteristic = nil
        connectionState = .disconnected
    }

    // MARK: - Status

    func fetchStatus() async throws -> BridgeStatus {
        try await ensureConnected()

        // Build status request command
        let command = buildCommand(type: 0x00, value: 0x00)

        // Send command and wait for response
        let response = try await sendCommand(command)

        // Parse response into BridgeStatus
        let status = try parseStatusResponse(response)
        lastStatus = status

        return status
    }

    // MARK: - Control

    func start() async throws {
        try await ensureConnected()

        // First set mode to manual (required before starting)
        let setModeCommand = buildCommand(type: 0x02, value: 0x01) // Manual mode
        try await sendControlCommand(setModeCommand)

        // Small delay to let mode change take effect
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Send start command
        let startCommand = buildCommand(type: 0x04, value: 0x01)
        try await sendControlCommand(startCommand)
    }

    func stop() async throws {
        try await ensureConnected()

        // Stop by setting speed to 0
        let command = buildCommand(type: 0x01, value: 0x00)
        try await sendControlCommand(command)
    }

    func setSpeed(_ kmh: Double) async throws {
        try await ensureConnected()

        // Clamp speed to valid range
        let clampedSpeed = max(0.0, min(6.0, kmh))

        // Convert km/h to raw value (multiply by 10)
        let speedRaw = UInt8(clampedSpeed * 10)

        let command = buildCommand(type: 0x01, value: speedRaw)
        try await sendControlCommand(command)
    }

    // MARK: - Private Connection Methods

    private func connect() async throws {
        guard centralManager.state == .poweredOn else {
            throw BridgeAPIError.bleFailure
        }

        connectionState = .connecting

        // Scan for WalkingPad
        let peripheral = try await scanForWalkingPad()
        self.peripheral = peripheral

        // Connect to peripheral
        try await connectToPeripheral(peripheral)

        // Discover services and characteristics
        try await discoverServices(peripheral)

        connectionState = .connected
    }

    private func scanForWalkingPad() async throws -> CBPeripheral {
        return try await withCheckedThrowingContinuation { continuation in
            scanContinuation = continuation

            // Start scanning for devices with the WalkingPad service
            centralManager.scanForPeripherals(
                withServices: [Self.serviceUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )

            // Set timeout
            Task {
                try? await Task.sleep(nanoseconds: UInt64(operationTimeout * 1_000_000_000))
                if scanContinuation != nil {
                    centralManager.stopScan()
                    scanContinuation?.resume(throwing: BridgeAPIError.padNotFound)
                    scanContinuation = nil
                }
            }
        }
    }

    private func connectToPeripheral(_ peripheral: CBPeripheral) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connectContinuation = continuation
            centralManager.connect(peripheral, options: nil)

            // Set timeout
            Task {
                try? await Task.sleep(nanoseconds: UInt64(operationTimeout * 1_000_000_000))
                if connectContinuation != nil {
                    centralManager.cancelPeripheralConnection(peripheral)
                    connectContinuation?.resume(throwing: BridgeAPIError.bleFailure)
                    connectContinuation = nil
                }
            }
        }
    }

    private func discoverServices(_ peripheral: CBPeripheral) async throws {
        peripheral.delegate = self

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            discoverContinuation = continuation
            peripheral.discoverServices([Self.serviceUUID])

            // Set timeout
            Task {
                try? await Task.sleep(nanoseconds: UInt64(operationTimeout * 1_000_000_000))
                if discoverContinuation != nil {
                    discoverContinuation?.resume(throwing: BridgeAPIError.bleFailure)
                    discoverContinuation = nil
                }
            }
        }
    }

    private func ensureConnected() throws {
        guard let peripheral = peripheral, peripheral.state == .connected else {
            throw BridgeAPIError.padNotConnected
        }

        guard readCharacteristic != nil, writeCharacteristic != nil else {
            throw BridgeAPIError.bleFailure
        }
    }

    // MARK: - Command Building

    private func buildCommand(type: UInt8, value: UInt8) -> Data {
        var command = Data()
        command.append(Self.header)
        command.append(Self.commandPrefix)
        command.append(type)
        command.append(value)

        // Calculate CRC (sum of payload bytes)
        let crc = UInt8((Int(Self.commandPrefix) + Int(type) + Int(value)) % 256)
        command.append(crc)
        command.append(Self.footer)

        return command
    }

    /// Sends a command and waits for a response (used for status requests)
    private func sendCommand(_ command: Data) async throws -> Data {
        guard let peripheral = peripheral,
              let writeChar = writeCharacteristic else {
            throw BridgeAPIError.padNotConnected
        }

        // Clear response buffer
        responseBuffer.removeAll()

        // Determine write type based on characteristic properties
        let writeType: CBCharacteristicWriteType
        if writeChar.properties.contains(.writeWithoutResponse) {
            writeType = .withoutResponse
        } else if writeChar.properties.contains(.write) {
            writeType = .withResponse
        } else {
            throw BridgeAPIError.bleFailure
        }

        // Set up continuation for response
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            readContinuation = continuation

            // Write command with appropriate type
            peripheral.writeValue(command, for: writeChar, type: writeType)

            // Set timeout
            Task {
                try? await Task.sleep(nanoseconds: UInt64(operationTimeout * 1_000_000_000))
                if readContinuation != nil {
                    readContinuation?.resume(throwing: BridgeAPIError.bleFailure)
                    readContinuation = nil
                }
            }
        }
    }

    /// Sends a control command without waiting for a response (used for start/stop/speed)
    private func sendControlCommand(_ command: Data) async throws {
        guard let peripheral = peripheral,
              let writeChar = writeCharacteristic else {
            throw BridgeAPIError.padNotConnected
        }

        // Determine write type based on characteristic properties
        let writeType: CBCharacteristicWriteType
        if writeChar.properties.contains(.writeWithoutResponse) {
            writeType = .withoutResponse
        } else if writeChar.properties.contains(.write) {
            writeType = .withResponse
        } else {
            throw BridgeAPIError.bleFailure
        }

        // Write command without waiting for response
        peripheral.writeValue(command, for: writeChar, type: writeType)

        // Small delay to ensure command is processed
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }

    // MARK: - Response Parsing

    private func parseStatusResponse(_ data: Data) throws -> BridgeStatus {
        // Status response format: [0xF8, 0xA2, state, speed_raw, mode, time_h, time_m, time_l, dist_h, dist_m, dist_l, steps_h, steps_m, steps_l, crc, 0xFD]
        guard data.count >= 16 else {
            throw BridgeAPIError.decodingError
        }

        guard data[0] == Self.statusHeader && data[1] == Self.commandPrefix else {
            throw BridgeAPIError.decodingError
        }

        // Parse state (byte 2)
        let stateRaw = Int(data[2])

        // Parse speed (byte 3) - divide by 10 for km/h
        let speedRaw = data[3]
        let speed = Double(speedRaw) / 10.0

        // Parse mode (byte 4)
        let modeRaw = Int(data[4])

        // Parse time (bytes 5-7) - 3-byte big-endian, seconds
        let timeHigh = Int(data[5])
        let timeMid = Int(data[6])
        let timeLow = Int(data[7])
        let time = (timeHigh << 16) | (timeMid << 8) | timeLow

        // Parse distance (bytes 8-10) - 3-byte big-endian, centimeters
        let distHigh = Int(data[8])
        let distMid = Int(data[9])
        let distLow = Int(data[10])
        let distanceCm = (distHigh << 16) | (distMid << 8) | distLow
        let distance = Double(distanceCm) / 100.0 // Convert cm to km (divide by 100000 for km, but this is already in meters so /100)

        // Parse steps (bytes 11-13) - 3-byte big-endian
        let stepsHigh = Int(data[11])
        let stepsMid = Int(data[12])
        let stepsLow = Int(data[13])
        let steps = (stepsHigh << 16) | (stepsMid << 8) | stepsLow

        // Determine if running
        let running = stateRaw == 1

        return BridgeStatus(
            time: time,
            distance: distance,
            steps: steps,
            speed: speed,
            state: stateRaw,
            mode: modeRaw,
            running: running
        )
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothPadService: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Bluetooth is ready
            break
        case .poweredOff, .unsupported, .unauthorized:
            connectionState = .error("Bluetooth unavailable")
            lastError = .bleFailure
        case .resetting, .unknown:
            break
        @unknown default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Check if device name matches WalkingPad patterns
        let name = peripheral.name ?? ""
        let matchesPattern = Self.deviceNamePatterns.contains { pattern in
            name.contains(pattern)
        }

        if matchesPattern {
            central.stopScan()
            scanContinuation?.resume(returning: peripheral)
            scanContinuation = nil
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectContinuation?.resume()
        connectContinuation = nil
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectContinuation?.resume(throwing: BridgeAPIError.bleFailure)
        connectContinuation = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionState = .disconnected
        self.peripheral = nil
        readCharacteristic = nil
        writeCharacteristic = nil
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothPadService: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            discoverContinuation?.resume(throwing: error)
            discoverContinuation = nil
            return
        }

        guard let services = peripheral.services,
              let service = services.first(where: { $0.uuid == Self.serviceUUID }) else {
            discoverContinuation?.resume(throwing: BridgeAPIError.bleFailure)
            discoverContinuation = nil
            return
        }

        // Discover characteristics
        peripheral.discoverCharacteristics([Self.readCharacteristicUUID, Self.writeCharacteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            discoverContinuation?.resume(throwing: error)
            discoverContinuation = nil
            return
        }

        guard let characteristics = service.characteristics else {
            discoverContinuation?.resume(throwing: BridgeAPIError.bleFailure)
            discoverContinuation = nil
            return
        }

        // Find read and write characteristics
        for characteristic in characteristics {
            if characteristic.uuid == Self.readCharacteristicUUID {
                readCharacteristic = characteristic
                // Subscribe to notifications
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == Self.writeCharacteristicUUID {
                writeCharacteristic = characteristic
            }
        }

        guard readCharacteristic != nil, writeCharacteristic != nil else {
            discoverContinuation?.resume(throwing: BridgeAPIError.bleFailure)
            discoverContinuation = nil
            return
        }

        discoverContinuation?.resume()
        discoverContinuation = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            readContinuation?.resume(throwing: error)
            readContinuation = nil
            return
        }

        guard let value = characteristic.value else {
            return
        }

        // Append to buffer
        responseBuffer.append(value)

        // Check if we have a complete message (starts with header, ends with footer)
        if responseBuffer.count >= 2 &&
           (responseBuffer[0] == Self.statusHeader || responseBuffer[0] == Self.header) &&
           responseBuffer.last == Self.footer {

            // We have a complete message
            if let continuation = readContinuation {
                continuation.resume(returning: responseBuffer)
                readContinuation = nil
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            readContinuation?.resume(throwing: error)
            readContinuation = nil
        }
        // Write completed successfully, now waiting for response via didUpdateValueFor
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating notification state: \(error.localizedDescription)")
        }
    }
}
