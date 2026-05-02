//
//  HeartRateMonitor.swift
//  Titan Native Module - BLE Heart Rate Monitor
//
//  Handles: BLE connection to heart rate monitors, background streaming, battery optimization
//  Uses: CoreBluetooth, Heart Rate Profile (UUID 0x180D)
//

import CoreBluetooth
import Flutter
import UIKit

// MARK: - Constants

struct HeartRateServiceUUID {
    static let heartRate = CBUUID(string: "180D")
    static let heartRateMeasurement = CBUUID(string: "2A37")
    static let bodySensorLocation = CBUUID(string: "2A38")
    static let heartRateControlPoint = CBUUID(string: "2A39")
    
    static let batteryService = CBUUID(string: "180F")
    static let batteryLevel = CBUUID(string: "2A19")
    
    static let deviceInfoService = CBUUID(string: "180A")
    static let manufacturerName = CBUUID(string: "2A29")
    static let modelNumber = CBUUID(string: "2A24")
}

// MARK: - Data Models

struct HeartRateReading: Codable {
    let bpm: Int
    let hrv: Double?  // Heart Rate Variability (if available)
    let source: String  // Device name
    let timestamp: Date
    let batteryLevel: Int?
    
    func toDictionary() -> [String: Any] {
        return [
            "bpm": bpm,
            "hrv": hrv ?? NSNull(),
            "source": source,
            "timestamp": timestamp.timeIntervalSince1970 * 1000,
            "batteryLevel": batteryLevel ?? NSNull()
        ]
    }
}

struct HeartRateDevice {
    let peripheral: CBPeripheral
    var name: String
    var rssi: Int
    var batteryLevel: Int?
    var isConnected: Bool = false
    
    init(peripheral: CBPeripheral, rssi: Int = 0) {
        self.peripheral = peripheral
        self.name = peripheral.name ?? "Unknown Device"
        self.rssi = rssi
    }
}

// MARK: - Heart Rate Monitor Delegate

protocol HeartRateMonitorDelegate: AnyObject {
    func didDiscoverDevice(_ device: HeartRateDevice)
    func didConnectToDevice(_ device: HeartRateDevice)
    func didDisconnectFromDevice(_ device: HeartRateDevice)
    func didReceiveHeartRate(_ reading: HeartRateReading)
    func didFailWithError(_ error: Error)
}

// MARK: - Heart Rate Monitor

class HeartRateMonitor: NSObject {
    
    // Singleton
    static let shared = HeartRateMonitor()
    
    // Core Bluetooth
    private let centralManager = CBCentralManager()
    
    // Devices
    private var discoveredDevices: [String: HeartRateDevice] = [:]
    private var connectedDevice: HeartRateDevice?
    
    // State
    private(set) var isScanning = false
    private(set) var isMonitoring = false
    
    // Buffer for batching
    private var readingBuffer: [HeartRateReading] = []
    private let batchSize = 10
    private var lastEmitTime: Date?
    
    // Delegate
    weak var delegate: HeartRateMonitorDelegate?
    
    // Flutter channel
    private var channel: FlutterMethodChannel?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        centralManager.delegate = self
    }
    
    // MARK: - Flutter Channel Setup
    
    func setupFlutterChannel(binaryMessenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.titan.app/heart_rate_monitor",
            binaryMessenger: binaryMessenger
        )
        
        channel?.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "startScan":
                self?.startScan()
                result(nil)
                
            case "stopScan":
                self?.stopScan()
                result(nil)
                
            case "getDiscoveredDevices":
                let devices = self?.getDiscoveredDevices()
                result(devices)
                
            case "connect":
                if let deviceId = call.arguments as? String {
                    self?.connect(deviceId: deviceId)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Device ID required", details: nil))
                }
                
            case "disconnect":
                self?.disconnect()
                result(nil)
                
            case "getConnectedDevice":
                let device = self?.getConnectedDeviceInfo()
                result(device)
                
            case "startMonitoring":
                self?.startMonitoring()
                result(nil)
                
            case "stopMonitoring":
                self?.stopMonitoring()
                result(nil)
                
            case "getLatestHeartRate":
                let reading = self?.readingBuffer.last?.toDictionary()
                result(reading)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // MARK: - Scanning
    
    func startScan() {
        guard centralManager.state == .poweredOn else {
            sendError("Bluetooth is not powered on")
            return
        }
        
        discoveredDevices.removeAll()
        isScanning = true
        
        // Scan for devices with heart rate service
        centralManager.scanForPeripherals(
            withServices: [HeartRateServiceUUID.heartRate],
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false
            ]
        )
        
        print("[HeartRateMonitor] Started scanning for HR devices")
    }
    
    func stopScan() {
        centralManager.stopScan()
        isScanning = false
        print("[HeartRateMonitor] Stopped scanning")
    }
    
    func getDiscoveredDevices() -> [[String: Any]] {
        return discoveredDevices.values.map { device in
            return [
                "id": device.peripheral.identifier.uuidString,
                "name": device.name,
                "rssi": device.rssi,
                "isConnected": device.isConnected
            ]
        }
    }
    
    // MARK: - Connection
    
    func connect(deviceId: String) {
        guard let device = discoveredDevices[deviceId] else {
            sendError("Device not found: \(deviceId)")
            return
        }
        
        // Stop scanning before connecting
        stopScan()
        
        centralManager.connect(device.peripheral, options: [
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])
        
        print("[HeartRateMonitor] Connecting to: \(device.name)")
    }
    
    func disconnect() {
        guard let device = connectedDevice else { return }
        
        centralManager.cancelPeripheralConnection(device.peripheral)
        connectedDevice = nil
        
        print("[HeartRateMonitor] Disconnected")
    }
    
    func getConnectedDeviceInfo() -> [String: Any]? {
        guard let device = connectedDevice else { return nil }
        return [
            "id": device.peripheral.identifier.uuidString,
            "name": device.name,
            "batteryLevel": device.batteryLevel ?? NSNull()
        ]
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        isMonitoring = true
        readingBuffer.removeAll()
        print("[HeartRateMonitor] Started monitoring")
    }
    
    func stopMonitoring() {
        isMonitoring = false
        emitBuffer()  // Flush remaining readings
        print("[HeartRateMonitor] Stopped monitoring")
    }
    
    // MARK: - Data Processing
    
    private func parseHeartRateMeasurement(data: Data) -> Int {
        // Heart Rate Measurement characteristic format
        // Flags byte: bit 0 = HR format (0 = UINT8, 1 = UINT16)
        //            bit 1-2 = Sensor contact status
        //            bit 3 = Energy expended present
        //            bit 4 = RR intervals present
        
        guard data.count >= 2 else { return 0 }
        
        let flags = data[0]
        let is16Bit = (flags & 0x01) != 0
        
        let bpm: Int
        if is16Bit {
            bpm = Int(data[1]) | (Int(data[2]) << 8)
        } else {
            bpm = Int(data[1])
        }
        
        return bpm
    }
    
    private func parseBatteryLevel(data: Data) -> Int {
        guard data.count >= 1 else { return 0 }
        return Int(data[0])
    }
    
    private func processHeartRate(bpm: Int, source: String) {
        let reading = HeartRateReading(
            bpm: bpm,
            hrv: nil,  // Would need RR intervals for HRV calculation
            source: source,
            timestamp: Date(),
            batteryLevel: connectedDevice?.batteryLevel
        )
        
        readingBuffer.append(reading)
        delegate?.didReceiveHeartRate(reading)
        
        // Check if we should emit batch
        if readingBuffer.count >= batchSize {
            emitBuffer()
        }
    }
    
    private func emitBuffer() {
        guard !readingBuffer.isEmpty else { return }
        
        let batch = readingBuffer.map { $0.toDictionary() }
        
        channel?.invokeMethod("onHeartRateBatch", arguments: [
            "readings": batch
        ])
        
        lastEmitTime = Date()
        readingBuffer.removeAll()
        
        print("[HeartRateMonitor] Emitted batch of \(batch.count) readings")
    }
    
    // MARK: - Error Handling
    
    private func sendError(_ message: String) {
        let error = NSError(domain: "HeartRateMonitor", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        delegate?.didFailWithError(error)
        channel?.invokeMethod("onError", arguments: message)
    }
}

// MARK: - CBCentralManagerDelegate

extension HeartRateMonitor: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("[HeartRateMonitor] Bluetooth powered on")
            channel?.invokeMethod("onBluetoothStateChanged", arguments: "poweredOn")
            
        case .poweredOff:
            print("[HeartRateMonitor] Bluetooth powered off")
            channel?.invokeMethod("onBluetoothStateChanged", arguments: "poweredOff")
            
        case .unauthorized:
            sendError("Bluetooth permission denied")
            
        case .unsupported:
            sendError("Bluetooth not supported on this device")
            
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceId = peripheral.identifier.uuidString
        
        // Update or add device
        var device = HeartRateDevice(peripheral: peripheral, rssi: RSSI.intValue)
        
        if let existing = discoveredDevices[deviceId] {
            device.isConnected = existing.isConnected
        }
        
        discoveredDevices[deviceId] = device
        
        // Notify Flutter
        channel?.invokeMethod("onDeviceDiscovered", arguments: [
            "id": deviceId,
            "name": device.name,
            "rssi": device.rssi
        ])
        
        delegate?.didDiscoverDevice(device)
        
        print("[HeartRateMonitor] Discovered: \(device.name) (\(deviceId))")
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let deviceId = peripheral.identifier.uuidString
        
        // Update device state
        discoveredDevices[deviceId]?.isConnected = true
        
        // Set as connected device
        if var device = discoveredDevices[deviceId] {
            device.isConnected = true
            connectedDevice = device
        }
        
        // Discover services
        peripheral.discoverServices([
            HeartRateServiceUUID.heartRate,
            HeartRateServiceUUID.batteryService,
            HeartRateServiceUUID.deviceInfoService
        ])
        
        // Notify
        channel?.invokeMethod("onDeviceConnected", arguments: [
            "id": deviceId,
            "name": connectedDevice?.name ?? "Unknown"
        ])
        
        delegate?.didConnectToDevice(connectedDevice!)
        
        print("[HeartRateMonitor] Connected to: \(connectedDevice?.name ?? "Unknown")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        
        // Update device state
        discoveredDevices[deviceId]?.isConnected = false
        
        // Clear connected device
        if connectedDevice?.peripheral.identifier.uuidString == deviceId {
            let disconnectedDevice = connectedDevice
            connectedDevice = nil
            delegate?.didDisconnectFromDevice(disconnectedDevice!)
        }
        
        // Notify
        channel?.invokeMethod("onDeviceDisconnected", arguments: [
            "id": deviceId
        ])
        
        print("[HeartRateMonitor] Disconnected from: \(deviceId)")
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        sendError("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
    }
}

// MARK: - CBPeripheralDelegate

extension HeartRateMonitor: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            sendError("Service discovery failed: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == HeartRateServiceUUID.heartRate {
                peripheral.discoverCharacteristics(
                    [HeartRateServiceUUID.heartRateMeasurement],
                    for: service
                )
            } else if service.uuid == HeartRateServiceUUID.batteryService {
                peripheral.discoverCharacteristics(
                    [HeartRateServiceUUID.batteryLevel],
                    for: service
                )
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == HeartRateServiceUUID.heartRateMeasurement {
                // Enable notifications for heart rate
                peripheral.setNotifyValue(true, for: characteristic)
                print("[HeartRateMonitor] Subscribed to heart rate notifications")
                
            } else if characteristic.uuid == HeartRateServiceUUID.batteryLevel {
                // Read battery level once
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        
        if characteristic.uuid == HeartRateServiceUUID.heartRateMeasurement {
            let bpm = parseHeartRateMeasurement(data: data)
            
            if bpm > 0 && isMonitoring {
                processHeartRate(bpm: bpm, source: connectedDevice?.name ?? "BLE")
                
                // Send real-time update
                channel?.invokeMethod("onHeartRateUpdate", arguments: [
                    "bpm": bpm,
                    "timestamp": Date().timeIntervalSince1970 * 1000
                ])
            }
            
        } else if characteristic.uuid == HeartRateServiceUUID.batteryLevel {
            let battery = parseBatteryLevel(data: data)
            connectedDevice?.batteryLevel = battery
            
            channel?.invokeMethod("onBatteryLevelUpdate", arguments: battery)
            print("[HeartRateMonitor] Battery level: \(battery)%")
        }
    }
}

// MARK: - Flutter Plugin Registration

class HeartRateMonitorPlugin: NSObject, FlutterPlugin {
    
    static func register(with registrar: FlutterPluginRegistrar) {
        HeartRateMonitor.shared.setupFlutterChannel(binaryMessenger: registrar.messenger())
    }
}