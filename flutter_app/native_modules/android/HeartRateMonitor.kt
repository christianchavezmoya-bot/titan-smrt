// HeartRateMonitor.kt
// Titan Native Module - Android BLE Heart Rate Monitor
// Handles: BLE connection to HR monitors, background streaming, battery optimization

package com.titan.app.native_modules

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.ParcelUuid
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

object HeartRateUUIDs {
    val HEART_RATE_SERVICE = UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb")
    val HEART_RATE_MEASUREMENT = UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb")
    val BATTERY_SERVICE = UUID.fromString("0000180f-0000-1000-8000-00805f9b34fb")
    val BATTERY_LEVEL = UUID.fromString("00002a19-0000-1000-8000-00805f9b34fb")
    val CCC_DESCRIPTOR = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
}

data class HeartRateReading(
    val bpm: Int,
    val hrv: Double?,
    val source: String,
    val timestamp: Long,
    val batteryLevel: Int?
)

data class HeartRateDevice(
    val device: BluetoothDevice,
    var name: String,
    var rssi: Int,
    var batteryLevel: Int? = null,
    var isConnected: Boolean = false
)

class HeartRateMonitor(private val context: Context) {
    
    companion object {
        const val BATCH_SIZE = 10
    }
    
    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager.adapter
    private val bluetoothLeScanner = bluetoothAdapter?.bluetoothLeScanner
    
    private var isScanning = false
    private var isMonitoring = false
    private var discoveredDevices: MutableMap<String, HeartRateDevice> = mutableMapOf()
    private var connectedDevice: HeartRateDevice? = null
    private var bluetoothGatt: BluetoothGatt? = null
    
    private var readingBuffer: MutableList<HeartRateReading> = mutableListOf()
    private var methodChannel: MethodChannel? = null
    
    // MARK: - Flutter Channel Setup
    
    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
    }
    
    // MARK: - Scanning
    
    fun startScan() {
        if (isScanning || bluetoothLeScanner == null) return
        
        if (!hasBluetoothPermission()) {
            methodChannel?.invokeMethod("onError", "Bluetooth permission not granted")
            return
        }
        
        discoveredDevices.clear()
        isScanning = true
        
        val filters = listOf(
            ScanFilter.Builder()
                .setServiceUuid(ParcelUuid(HeartRateUUIDs.HEART_RATE_SERVICE))
                .build()
        )
        
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        
        bluetoothLeScanner.startScan(filters, settings, scanCallback)
    }
    
    fun stopScan() {
        if (!isScanning || bluetoothLeScanner == null) return
        bluetoothLeScanner.stopScan(scanCallback)
        isScanning = false
    }
    
    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device
            val deviceId = device.address
            
            val hrDevice = HeartRateDevice(
                device = device,
                name = device.name ?: "Unknown Device",
                rssi = result.rssi
            )
            
            discoveredDevices[deviceId] = hrDevice
            
            methodChannel?.invokeMethod("onDeviceDiscovered", mapOf(
                "id" to deviceId,
                "name" to hrDevice.name,
                "rssi" to hrDevice.rssi
            ))
        }
        
        override fun onScanFailed(errorCode: Int) {
            methodChannel?.invokeMethod("onError", "Scan failed with error: $errorCode")
        }
    }
    
    // MARK: - Connection
    
    fun connect(deviceId: String) {
        val device = discoveredDevices[deviceId] ?: return
        
        if (!hasBluetoothPermission()) return
        
        stopScan()
        
        bluetoothGatt = device.device.connectGatt(
            context,
            false,
            gattCallback,
            BluetoothDevice.TRANSPORT_LE
        )
    }
    
    fun disconnect() {
        bluetoothGatt?.close()
        bluetoothGatt = null
        connectedDevice = null
    }
    
    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    gatt.discoverServices()
                    methodChannel?.invokeMethod("onDeviceConnected", mapOf(
                        "id" to gatt.device.address,
                        "name" to connectedDevice?.name ?: "Unknown"
                    ))
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    methodChannel?.invokeMethod("onDeviceDisconnected", mapOf(
                        "id" to gatt.device.address
                    ))
                }
            }
        }
        
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) return
            
            // Subscribe to heart rate measurement
            val hrService = gatt.getService(HeartRateUUIDs.HEART_RATE_SERVICE)
            hrService?.getCharacteristic(HeartRateUUIDs.HEART_RATE_MEASUREMENT)?.let { char ->
                enableNotification(gatt, char)
            }
            
            // Read battery level
            val batteryService = gatt.getService(HeartRateUUIDs.BATTERY_SERVICE)
            batteryService?.getCharacteristic(HeartRateUUIDs.BATTERY_LEVEL)?.let { char ->
                gatt.readCharacteristic(char)
            }
        }
        
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            if (characteristic.uuid == HeartRateUUIDs.HEART_RATE_MEASUREMENT) {
                val bpm = parseHeartRate(characteristic)
                if (bpm > 0 && isMonitoring) {
                    processHeartRate(bpm)
                }
            }
        }
        
        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            if (characteristic.uuid == HeartRateUUIDs.BATTERY_LEVEL) {
                val battery = characteristic.value?.firstOrNull()?.toInt() ?: 0
                connectedDevice?.batteryLevel = battery
                methodChannel?.invokeMethod("onBatteryLevelUpdate", battery)
            }
        }
    }
    
    private fun enableNotification(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
        gatt.setCharacteristicNotification(characteristic, true)
        
        val descriptor = characteristic.getDescriptor(HeartRateUUIDs.CCC_DESCRIPTOR)
        descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        gatt.writeDescriptor(descriptor)
    }
    
    // MARK: - Data Processing
    
    private fun parseHeartRate(characteristic: BluetoothGattCharacteristic): Int {
        val flags = characteristic.getIntValue(BluetoothGattCharacteristic.FORMAT_UINT8, 0)
        val is16Bit = (flags and 0x01) != 0
        
        return if (is16Bit) {
            characteristic.getIntValue(BluetoothGattCharacteristic.FORMAT_UINT16, 1)
        } else {
            characteristic.getIntValue(BluetoothGattCharacteristic.FORMAT_UINT8, 1)
        }
    }
    
    private fun processHeartRate(bpm: Int) {
        val reading = HeartRateReading(
            bpm = bpm,
            hrv = null,
            source = connectedDevice?.name ?: "BLE",
            timestamp = System.currentTimeMillis(),
            batteryLevel = connectedDevice?.batteryLevel
        )
        
        readingBuffer.add(reading)
        
        methodChannel?.invokeMethod("onHeartRateUpdate", mapOf(
            "bpm" to bpm,
            "timestamp" to reading.timestamp
        ))
        
        if (readingBuffer.size >= BATCH_SIZE) {
            emitBuffer()
        }
    }
    
    private fun emitBuffer() {
        if (readingBuffer.isEmpty()) return
        
        val batch = readingBuffer.map { reading ->
            mapOf(
                "bpm" to reading.bpm,
                "hrv" to reading.hrv,
                "source" to reading.source,
                "timestamp" to reading.timestamp,
                "batteryLevel" to reading.batteryLevel
            )
        }
        
        methodChannel?.invokeMethod("onHeartRateBatch", mapOf("readings" to batch))
        readingBuffer.clear()
    }
    
    // MARK: - Monitoring Control
    
    fun startMonitoring() {
        isMonitoring = true
        readingBuffer.clear()
    }
    
    fun stopMonitoring() {
        isMonitoring = false
        emitBuffer()
    }
    
    // MARK: - Helpers
    
    private fun hasBluetoothPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }
    
    fun getDiscoveredDevices(): List<Map<String, Any>> {
        return discoveredDevices.values.map { device ->
            mapOf(
                "id" to device.device.address,
                "name" to device.name,
                "rssi" to device.rssi,
                "isConnected" to device.isConnected
            )
        }
    }
    
    fun getConnectedDeviceInfo(): Map<String, Any>? {
        return connectedDevice?.let { device ->
            mapOf(
                "id" to device.device.address,
                "name" to device.name,
                "batteryLevel" to device.batteryLevel
            )
        }
    }
    
    fun getLatestHeartRate(): Map<String, Any>? {
        return readingBuffer.lastOrNull()?.let { reading ->
            mapOf(
                "bpm" to reading.bpm,
                "timestamp" to reading.timestamp
            )
        }
    }
    
    fun isScanning(): Boolean = isScanning
    fun isMonitoring(): Boolean = isMonitoring
}

// Flutter Plugin
class HeartRateMonitorPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
    
    private val monitor = HeartRateMonitor(context)
    private var methodChannel: MethodChannel? = null
    
    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
        monitor.setMethodChannel(channel)
        channel.setMethodCallHandler(this)
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startScan" -> { monitor.startScan(); result.success(null) }
            "stopScan" -> { monitor.stopScan(); result.success(null) }
            "getDiscoveredDevices" -> result.success(monitor.getDiscoveredDevices())
            "connect" -> { monitor.connect(call.argument<String>("deviceId")!!); result.success(null) }
            "disconnect" -> { monitor.disconnect(); result.success(null) }
            "getConnectedDevice" -> result.success(monitor.getConnectedDeviceInfo())
            "startMonitoring" -> { monitor.startMonitoring(); result.success(null) }
            "stopMonitoring" -> { monitor.stopMonitoring(); result.success(null) }
            "getLatestHeartRate" -> result.success(monitor.getLatestHeartRate())
            "isMonitoring" -> result.success(monitor.isMonitoring())
            else -> result.notImplemented()
        }
    }
}