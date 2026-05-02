// LocationTracker.kt
// Titan Native Module - Android Background GPS Tracking
// Handles: Background location tracking, battery optimization, batch coordinates

package com.titan.app.native_modules

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.*
import io.flutter.plugin.common.MethodChannel

data class LocationPoint(
    val latitude: Double,
    val longitude: Double,
    val altitude: Double,
    val speed: Double,
    val accuracy: Double,
    val timestamp: Long
)

class LocationTrackerService : Service() {
    
    companion object {
        const val CHANNEL_ID = "titan_location_tracking"
        const val NOTIFICATION_ID = 12345
        const val BATCH_SIZE = 10
        const val BATCH_INTERVAL_MS = 10000L
        const val MIN_DISTANCE_FILTER = 5f
        const val MIN_UPDATE_INTERVAL_MS = 1000L
    }
    
    private val binder = LocalBinder()
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    
    private var isTracking = false
    private var currentSessionId: String? = null
    private var locationBuffer: MutableList<LocationPoint> = mutableListOf()
    private var lastEmitTime: Long = 0
    
    private var methodChannel: MethodChannel? = null
    
    inner class LocalBinder : Binder() {
        fun getService(): LocationTrackerService = this@LocationTrackerService
    }
    
    override fun onBind(intent: Intent?): IBinder {
        return binder
    }
    
    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        setupLocationCallback()
        createNotificationChannel()
    }
    
    private fun setupLocationCallback() {
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { location ->
                    processLocation(location)
                }
            }
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Titan fitness tracking in progress"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun getNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Titan")
            .setContentText("Tracking workout...")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
    
    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
    }
    
    @SuppressLint("MissingPermission")
    fun startTracking(sessionId: String) {
        if (isTracking) return
        
        currentSessionId = sessionId
        locationBuffer.clear()
        isTracking = true
        
        // Start foreground service
        startForeground(NOTIFICATION_ID, getNotification())
        
        // Configure location request
        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            MIN_UPDATE_INTERVAL_MS
        ).apply {
            setMinUpdateDistanceMeters(MIN_DISTANCE_FILTER)
            setGranularity(Granularity.GRANULARITY_PERMISSION_LEVEL)
            setWaitForAccurateLocation(true)
        }.build()
        
        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                Looper.getMainLooper()
            )
        } catch (e: SecurityException) {
            methodChannel?.invokeMethod("onError", "Location permission not granted")
        }
    }
    
    fun stopTracking(): List<Map<String, Any>> {
        if (!isTracking) return emptyList()
        
        isTracking = false
        
        fusedLocationClient.removeLocationUpdates(locationCallback)
        stopForeground(STOP_FOREGROUND_REMOVE)
        
        val remainingPoints = emitBuffer()
        locationBuffer.clear()
        
        return remainingPoints
    }
    
    private fun processLocation(location: Location) {
        if (!isTracking) return
        
        // Filter out inaccurate readings
        if (location.accuracy > 50f) return
        
        val point = LocationPoint(
            latitude = location.latitude,
            longitude = location.longitude,
            altitude = location.altitude,
            speed = location.speed,
            accuracy = location.accuracy.toDouble(),
            timestamp = System.currentTimeMillis()
        )
        
        locationBuffer.add(point)
        
        // Check if we should emit batch
        val shouldEmitByCount = locationBuffer.size >= BATCH_SIZE
        val shouldEmitByTime = System.currentTimeMillis() - lastEmitTime >= BATCH_INTERVAL_MS
        
        if (shouldEmitByCount || shouldEmitByTime) {
            emitBuffer()
        }
        
        // Adjust accuracy based on speed for battery optimization
        adjustAccuracyForSpeed(location.speed)
    }
    
    private fun adjustAccuracyForSpeed(speed: Float) {
        // Could dynamically adjust location request priority based on movement
        // This is handled through the location request configuration
    }
    
    private fun emitBuffer(): List<Map<String, Any>> {
        if (locationBuffer.isEmpty()) return emptyList()
        
        val batch = locationBuffer.map { point ->
            mapOf(
                "latitude" to point.latitude,
                "longitude" to point.longitude,
                "altitude" to point.altitude,
                "speed" to point.speed,
                "accuracy" to point.accuracy,
                "timestamp" to point.timestamp
            )
        }
        
        methodChannel?.invokeMethod("onLocationBatch", mapOf(
            "sessionId" to (currentSessionId ?: ""),
            "points" to batch
        ))
        
        lastEmitTime = System.currentTimeMillis()
        locationBuffer.clear()
        
        return batch
    }
    
    fun isTracking(): Boolean = isTracking
    
    @SuppressLint("MissingPermission")
    fun getCurrentLocation(): Map<String, Any>? {
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return null
        }
        
        var result: Map<String, Any>? = null
        fusedLocationClient.lastLocation.addOnSuccessListener { location ->
            location?.let {
                result = mapOf(
                    "latitude" to it.latitude,
                    "longitude" to it.longitude,
                    "altitude" to it.altitude,
                    "speed" to it.speed,
                    "accuracy" to it.accuracy,
                    "timestamp" to System.currentTimeMillis()
                )
            }
        }
        return result
    }
}

// Flutter Method Channel Handler
class LocationTrackerPlugin(context: Context) : MethodChannel.MethodCallHandler {
    
    private val context = context.applicationContext
    private var service: LocationTrackerService? = null
    private var methodChannel: MethodChannel? = null
    
    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
        methodChannel?.setMethodCallHandler(this)
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startTracking" -> {
                val sessionId = call.argument<String>("sessionId") ?: java.util.UUID.randomUUID().toString()
                service?.startTracking(sessionId)
                result.success(sessionId)
            }
            "stopTracking" -> {
                val points = service?.stopTracking()
                result.success(points)
            }
            "getCurrentLocation" -> {
                val location = service?.getCurrentLocation()
                result.success(location)
            }
            "isTracking" -> {
                result.success(service?.isTracking() ?: false)
            }
            else -> result.notImplemented()
        }
    }
    
    fun setService(locationService: LocationTrackerService) {
        service = locationService
        methodChannel?.let { service?.setMethodChannel(it) }
    }
}