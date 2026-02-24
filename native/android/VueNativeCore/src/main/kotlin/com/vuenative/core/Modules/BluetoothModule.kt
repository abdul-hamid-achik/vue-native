package com.vuenative.core

import android.Manifest
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Base64
import androidx.core.content.ContextCompat
import java.util.UUID

class BluetoothModule : NativeModule {
    override val moduleName = "Bluetooth"

    private var context: Context? = null
    private var bridge: NativeBridge? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var scanner: BluetoothLeScanner? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val discoveredDevices = mutableMapOf<String, BluetoothDevice>()
    private val gattConnections = mutableMapOf<String, BluetoothGatt>()
    private val connectCallbacks = mutableMapOf<String, (Any?, String?) -> Unit>()
    private val readCallbacks = mutableMapOf<String, (Any?, String?) -> Unit>()
    private val writeCallbacks = mutableMapOf<String, (Any?, String?) -> Unit>()

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context
        this.bridge = bridge
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter
        scanner = bluetoothAdapter?.bluetoothLeScanner
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        when (method) {
            "startScan" -> {
                if (!hasBluetoothPermission()) {
                    callback(null, "Bluetooth permission not granted")
                    return
                }
                val serviceUUIDs = (args.getOrNull(0) as? List<*>)?.filterIsInstance<String>()
                startScan(serviceUUIDs)
                callback(null, null)
            }
            "stopScan" -> {
                stopScan()
                callback(null, null)
            }
            "connect" -> {
                val deviceId = args.getOrNull(0)?.toString() ?: run {
                    callback(null, "Missing deviceId"); return
                }
                connect(deviceId, callback)
            }
            "disconnect" -> {
                val deviceId = args.getOrNull(0)?.toString() ?: run {
                    callback(null, "Missing deviceId"); return
                }
                disconnect(deviceId, callback)
            }
            "readCharacteristic" -> {
                val deviceId = args.getOrNull(0)?.toString() ?: run { callback(null, "Missing deviceId"); return }
                val serviceUUID = args.getOrNull(1)?.toString() ?: run { callback(null, "Missing serviceUUID"); return }
                val charUUID = args.getOrNull(2)?.toString() ?: run { callback(null, "Missing charUUID"); return }
                readCharacteristic(deviceId, serviceUUID, charUUID, callback)
            }
            "writeCharacteristic" -> {
                val deviceId = args.getOrNull(0)?.toString() ?: run { callback(null, "Missing deviceId"); return }
                val serviceUUID = args.getOrNull(1)?.toString() ?: run { callback(null, "Missing serviceUUID"); return }
                val charUUID = args.getOrNull(2)?.toString() ?: run { callback(null, "Missing charUUID"); return }
                val dataBase64 = args.getOrNull(3)?.toString() ?: run { callback(null, "Missing data"); return }
                writeCharacteristic(deviceId, serviceUUID, charUUID, dataBase64, callback)
            }
            "subscribeToCharacteristic" -> {
                val deviceId = args.getOrNull(0)?.toString() ?: run { callback(null, "Missing deviceId"); return }
                val serviceUUID = args.getOrNull(1)?.toString() ?: run { callback(null, "Missing serviceUUID"); return }
                val charUUID = args.getOrNull(2)?.toString() ?: run { callback(null, "Missing charUUID"); return }
                subscribeToCharacteristic(deviceId, serviceUUID, charUUID, callback)
            }
            "unsubscribeFromCharacteristic" -> {
                val deviceId = args.getOrNull(0)?.toString() ?: run { callback(null, "Missing deviceId"); return }
                val serviceUUID = args.getOrNull(1)?.toString() ?: run { callback(null, "Missing serviceUUID"); return }
                val charUUID = args.getOrNull(2)?.toString() ?: run { callback(null, "Missing charUUID"); return }
                unsubscribeFromCharacteristic(deviceId, serviceUUID, charUUID, callback)
            }
            "getState" -> {
                val state = when {
                    bluetoothAdapter == null -> "unsupported"
                    bluetoothAdapter?.isEnabled != true -> "poweredOff"
                    else -> "poweredOn"
                }
                callback(state, null)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }

    private fun hasBluetoothPermission(): Boolean {
        val ctx = context ?: return false
        return if (Build.VERSION.SDK_INT >= 31) {
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }
    }

    @Suppress("MissingPermission")
    private fun startScan(serviceUUIDs: List<String>?) {
        val filters = serviceUUIDs?.map { uuid ->
            ScanFilter.Builder().setServiceUuid(android.os.ParcelUuid(UUID.fromString(uuid))).build()
        }
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        scanner?.startScan(filters, settings, scanCallback)
    }

    @Suppress("MissingPermission")
    private fun stopScan() {
        scanner?.stopScan(scanCallback)
    }

    @Suppress("MissingPermission")
    private fun connect(deviceId: String, callback: (Any?, String?) -> Unit) {
        val device = discoveredDevices[deviceId]
        if (device == null) {
            callback(null, "Device not found: $deviceId")
            return
        }
        connectCallbacks[deviceId] = callback
        device.connectGatt(context, false, gattCallback)
    }

    @Suppress("MissingPermission")
    private fun disconnect(deviceId: String, callback: (Any?, String?) -> Unit) {
        val gatt = gattConnections[deviceId]
        if (gatt == null) {
            callback(null, "Device not connected: $deviceId")
            return
        }
        gatt.disconnect()
        gatt.close()
        gattConnections.remove(deviceId)
        callback(null, null)
    }

    @Suppress("MissingPermission")
    private fun readCharacteristic(deviceId: String, serviceUUID: String, charUUID: String, callback: (Any?, String?) -> Unit) {
        val gatt = gattConnections[deviceId] ?: run { callback(null, "Device not connected"); return }
        val char = findCharacteristic(gatt, serviceUUID, charUUID) ?: run { callback(null, "Characteristic not found"); return }
        val key = "$deviceId:$serviceUUID:$charUUID"
        readCallbacks[key] = callback
        gatt.readCharacteristic(char)
    }

    @Suppress("MissingPermission")
    private fun writeCharacteristic(deviceId: String, serviceUUID: String, charUUID: String, dataBase64: String, callback: (Any?, String?) -> Unit) {
        val gatt = gattConnections[deviceId] ?: run { callback(null, "Device not connected"); return }
        val char = findCharacteristic(gatt, serviceUUID, charUUID) ?: run { callback(null, "Characteristic not found"); return }
        val data = Base64.decode(dataBase64, Base64.DEFAULT)
        val key = "$deviceId:$serviceUUID:$charUUID"
        writeCallbacks[key] = callback
        char.value = data
        gatt.writeCharacteristic(char)
    }

    @Suppress("MissingPermission")
    private fun subscribeToCharacteristic(deviceId: String, serviceUUID: String, charUUID: String, callback: (Any?, String?) -> Unit) {
        val gatt = gattConnections[deviceId] ?: run { callback(null, "Device not connected"); return }
        val char = findCharacteristic(gatt, serviceUUID, charUUID) ?: run { callback(null, "Characteristic not found"); return }
        gatt.setCharacteristicNotification(char, true)
        val descriptor = char.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"))
        descriptor?.let {
            it.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            gatt.writeDescriptor(it)
        }
        callback(null, null)
    }

    @Suppress("MissingPermission")
    private fun unsubscribeFromCharacteristic(deviceId: String, serviceUUID: String, charUUID: String, callback: (Any?, String?) -> Unit) {
        val gatt = gattConnections[deviceId] ?: run { callback(null, "Device not connected"); return }
        val char = findCharacteristic(gatt, serviceUUID, charUUID) ?: run { callback(null, "Characteristic not found"); return }
        gatt.setCharacteristicNotification(char, false)
        callback(null, null)
    }

    private fun findCharacteristic(gatt: BluetoothGatt, serviceUUID: String, charUUID: String): BluetoothGattCharacteristic? {
        val service = gatt.getService(UUID.fromString(serviceUUID)) ?: return null
        return service.getCharacteristic(UUID.fromString(charUUID))
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device
            @Suppress("MissingPermission")
            val name = device.name ?: ""
            val id = device.address
            discoveredDevices[id] = device
            mainHandler.post {
                bridge?.dispatchGlobalEvent("ble:deviceFound", mapOf(
                    "id" to id,
                    "name" to name,
                    "rssi" to result.rssi,
                ))
            }
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        @Suppress("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            val deviceId = gatt.device.address
            mainHandler.post {
                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        gattConnections[deviceId] = gatt
                        gatt.discoverServices()
                        val payload = mapOf("id" to deviceId, "name" to (gatt.device.name ?: ""))
                        bridge?.dispatchGlobalEvent("ble:connected", payload)
                        connectCallbacks.remove(deviceId)?.invoke(payload, null)
                    }
                    BluetoothProfile.STATE_DISCONNECTED -> {
                        gattConnections.remove(deviceId)
                        gatt.close()
                        bridge?.dispatchGlobalEvent("ble:disconnected", mapOf("id" to deviceId))
                    }
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            // Services are now available for read/write/subscribe
        }

        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            val deviceId = gatt.device.address
            val serviceUUID = characteristic.service.uuid.toString()
            val charUUID = characteristic.uuid.toString()
            val key = "$deviceId:$serviceUUID:$charUUID"
            val valueBase64 = Base64.encodeToString(characteristic.value ?: ByteArray(0), Base64.NO_WRAP)
            mainHandler.post {
                val cb = readCallbacks.remove(key)
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    cb?.invoke(mapOf(
                        "value" to valueBase64,
                        "characteristicUUID" to charUUID,
                        "serviceUUID" to serviceUUID,
                    ), null)
                } else {
                    cb?.invoke(null, "Read failed with status: $status")
                }
            }
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            val deviceId = gatt.device.address
            val serviceUUID = characteristic.service.uuid.toString()
            val charUUID = characteristic.uuid.toString()
            val key = "$deviceId:$serviceUUID:$charUUID"
            mainHandler.post {
                val cb = writeCallbacks.remove(key)
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    cb?.invoke(null, null)
                } else {
                    cb?.invoke(null, "Write failed with status: $status")
                }
            }
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            val deviceId = gatt.device.address
            val serviceUUID = characteristic.service.uuid.toString()
            val charUUID = characteristic.uuid.toString()
            val valueBase64 = Base64.encodeToString(characteristic.value ?: ByteArray(0), Base64.NO_WRAP)
            mainHandler.post {
                bridge?.dispatchGlobalEvent("ble:characteristicChanged", mapOf(
                    "deviceId" to deviceId,
                    "serviceUUID" to serviceUUID,
                    "characteristicUUID" to charUUID,
                    "value" to valueBase64,
                ))
            }
        }
    }

    override fun destroy() {
        @Suppress("MissingPermission")
        scanner?.stopScan(scanCallback)
        gattConnections.values.forEach {
            @Suppress("MissingPermission")
            it.disconnect()
            it.close()
        }
        gattConnections.clear()
    }
}
