//
//  LocationTracker.swift
//  Titan Native Module - Background GPS Tracking
//
//  Handles: Background location tracking, optimized battery usage, batch coordinates
//  Uses: CoreLocation for GPS, Flutter Method Channel bridge
//

import CoreLocation
import Flutter
import UIKit

// MARK: - Location Data Model
struct LocationPoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let speed: Double
    let accuracy: Double
    let timestamp: Date
    
    func toDictionary() -> [String: Any] {
        return [
            "latitude": latitude,
            "longitude": longitude,
            "altitude": altitude,
            "speed": speed,
            "accuracy": accuracy,
            "timestamp": timestamp.timeIntervalSince1970 * 1000
        ]
    }
}

// MARK: - Location Tracker Delegate Protocol
protocol LocationTrackerDelegate: AnyObject {
    func didUpdateLocations(_ locations: [LocationPoint])
    func didChangeAuthorization(_ status: CLAuthorizationStatus)
    func didFailWithError(_ error: Error)
}

// MARK: - Location Tracker
class LocationTracker: NSObject {
    
    // Singleton instance
    static let shared = LocationTracker()
    
    // Location manager
    private let locationManager = CLLocationManager()
    
    // Delegate
    weak var delegate: LocationTrackerDelegate?
    
    // Tracking state
    private(set) var isTracking = false
    private var currentSessionId: String?
    
    // Batch storage
    private var locationBuffer: [LocationPoint] = []
    private let batchSize = 10  // Emit every 10 points
    private let batchInterval: TimeInterval = 10  // Or every 10 seconds
    
    // Battery optimization
    private var lastEmitTime: Date?
    private let minDistanceFilter: CLLocationDistance = 5  // meters
    private let minUpdateTime: TimeInterval = 1  // seconds
    
    // Flutter binary messenger
    private var channel: FlutterMethodChannel?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = minDistanceFilter
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
        
        // Request permissions
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - Flutter Channel Setup
    
    func setupFlutterChannel(binaryMessenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.titan.app/location_tracker",
            binaryMessenger: binaryMessenger
        )
        
        channel?.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "startTracking":
                let sessionId = call.arguments as? String ?? UUID().uuidString
                self?.startTracking(sessionId: sessionId)
                result(sessionId)
                
            case "stopTracking":
                let points = self?.stopTracking()
                result(points)
                
            case "getCurrentLocation":
                self?.getCurrentLocation(result: result)
                
            case "isTracking":
                result(self?.isTracking ?? false)
                
            case "requestPermission":
                self?.requestPermission()
                result(nil)
                
            case "hasPermission":
                let status = CLLocationManager.authorizationStatus()
                result(status == .authorizedAlways || status == .authorizedWhenInUse)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // MARK: - Public Methods
    
    func startTracking(sessionId: String) {
        guard !isTracking else { return }
        
        currentSessionId = sessionId
        locationBuffer.removeAll()
        isTracking = true
        
        // Enable significant location change monitoring for battery efficiency
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startUpdatingLocation()
        
        // Start background task
        startBackgroundTask()
        
        print("[LocationTracker] Started tracking session: \(sessionId)")
    }
    
    func stopTracking() -> [[String: Any]] {
        guard isTracking else { return [] }
        
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        
        // Flush remaining buffer
        let remainingPoints = locationBuffer.map { $0.toDictionary() }
        locationBuffer.removeAll()
        
        print("[LocationTracker] Stopped tracking. Remaining points: \(remainingPoints.count)")
        
        return remainingPoints
    }
    
    func getCurrentLocation(result: @escaping FlutterResult) {
        guard let location = locationManager.location else {
            result(FlutterError(code: "NO_LOCATION", message: "No location available", details: nil))
            return
        }
        
        let point = LocationPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            speed: location.speed,
            accuracy: location.horizontalAccuracy,
            timestamp: location.timestamp
        )
        
        result(point.toDictionary())
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - Battery Optimization
    
    private func adjustAccuracyBasedOnSpeed(speed: Double) {
        // Reduce accuracy when stationary to save battery
        if speed < 1 {
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        } else if speed < 5 {
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        } else {
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        }
    }
    
    // MARK: - Background Task Management
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    private func startBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "LocationTracking") { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    // MARK: - Location Processing
    
    private func processLocation(_ location: CLLocation) {
        let point = LocationPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            speed: location.speed,
            accuracy: location.horizontalAccuracy,
            timestamp: location.timestamp
        )
        
        // Filter out inaccurate readings
        guard point.accuracy < 50 else { return }
        
        // Adjust accuracy based on speed for battery optimization
        adjustAccuracyBasedOnSpeed(speed: point.speed)
        
        // Add to buffer
        locationBuffer.append(point)
        
        // Check if we should emit batch
        let shouldEmitByCount = locationBuffer.count >= batchSize
        let shouldEmitByTime: Bool
        
        if let lastEmit = lastEmitTime {
            shouldEmitByTime = Date().timeIntervalSince(lastEmit) >= batchInterval
        } else {
            shouldEmitByTime = false
        }
        
        if shouldEmitByCount || shouldEmitByTime {
            emitBatch()
        }
    }
    
    private func emitBatch() {
        guard !locationBuffer.isEmpty else { return }
        
        let batch = locationBuffer.map { $0.toDictionary() }
        lastEmitTime = Date()
        
        // Send to Flutter
        channel?.invokeMethod("onLocationBatch", arguments: [
            "sessionId": currentSessionId ?? "",
            "points": batch
        ])
        
        // Notify delegate
        delegate?.didUpdateLocations(locationBuffer)
        
        // Clear buffer
        locationBuffer.removeAll()
        
        print("[LocationTracker] Emitted batch of \(batch.count) locations")
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationTracker: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking else { return }
        
        for location in locations {
            processLocation(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        delegate?.didChangeAuthorization(status)
        
        channel?.invokeMethod("onAuthorizationChanged", arguments: authorizationStatusToString(status))
        
        if status == .authorizedAlways {
            // Enable background tracking
            locationManager.allowsBackgroundLocationUpdates = true
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationTracker] Error: \(error.localizedDescription)")
        delegate?.didFailWithError(error)
        
        channel?.invokeMethod("onError", arguments: error.localizedDescription)
    }
    
    private func authorizationStatusToString(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - Flutter Plugin Registration

class LocationTrackerPlugin: NSObject, FlutterPlugin {
    
    static func register(with registrar: FlutterPluginRegistrar) {
        LocationTracker.shared.setupFlutterChannel(binaryMessenger: registrar.messenger())
    }
}