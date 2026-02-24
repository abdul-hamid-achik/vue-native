#if canImport(UIKit)
import UIKit
import CoreBluetooth

/// Native module for Bluetooth Low Energy (BLE) operations.
///
/// Methods:
///   - startScan(serviceUUIDs?: [String]) — start scanning for peripherals
///   - stopScan() — stop scanning
///   - connect(deviceId: String) — connect to a peripheral
///   - disconnect(deviceId: String) — disconnect from a peripheral
///   - readCharacteristic(deviceId, serviceUUID, charUUID) — read a characteristic
///   - writeCharacteristic(deviceId, serviceUUID, charUUID, data) — write a characteristic
///   - subscribeToCharacteristic(deviceId, serviceUUID, charUUID) — subscribe to notifications
///   - unsubscribeFromCharacteristic(deviceId, serviceUUID, charUUID)
///   - getState() — returns current Bluetooth state
///
/// Events:
///   - ble:deviceFound — peripheral discovered
///   - ble:connected — peripheral connected
///   - ble:disconnected — peripheral disconnected
///   - ble:characteristicChanged — characteristic value updated
///   - ble:stateChanged — Bluetooth state changed
///   - ble:error — error occurred
final class BluetoothModule: NativeModule {
    var moduleName: String { "Bluetooth" }
    private weak var bridge: NativeBridge?

    init(bridge: NativeBridge) { self.bridge = bridge }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        let weakBridge = bridge
        switch method {
        case "startScan":
            let serviceUUIDs = (args.first as? [String])
            DispatchQueue.main.async {
                BLEManager.shared.startScan(serviceUUIDs: serviceUUIDs, bridge: weakBridge)
                callback(nil, nil)
            }
        case "stopScan":
            DispatchQueue.main.async {
                BLEManager.shared.stopScan()
                callback(nil, nil)
            }
        case "connect":
            guard let deviceId = args.first as? String else {
                callback(nil, "BluetoothModule: missing deviceId"); return
            }
            DispatchQueue.main.async {
                BLEManager.shared.connect(deviceId: deviceId, bridge: weakBridge, callback: callback)
            }
        case "disconnect":
            guard let deviceId = args.first as? String else {
                callback(nil, "BluetoothModule: missing deviceId"); return
            }
            DispatchQueue.main.async {
                BLEManager.shared.disconnect(deviceId: deviceId, callback: callback)
            }
        case "readCharacteristic":
            guard let deviceId = args[safe: 0] as? String,
                  let serviceUUID = args[safe: 1] as? String,
                  let charUUID = args[safe: 2] as? String else {
                callback(nil, "BluetoothModule: missing deviceId/serviceUUID/charUUID"); return
            }
            DispatchQueue.main.async {
                BLEManager.shared.readCharacteristic(
                    deviceId: deviceId, serviceUUID: serviceUUID, charUUID: charUUID, callback: callback
                )
            }
        case "writeCharacteristic":
            guard let deviceId = args[safe: 0] as? String,
                  let serviceUUID = args[safe: 1] as? String,
                  let charUUID = args[safe: 2] as? String,
                  let dataBase64 = args[safe: 3] as? String else {
                callback(nil, "BluetoothModule: missing args for writeCharacteristic"); return
            }
            DispatchQueue.main.async {
                BLEManager.shared.writeCharacteristic(
                    deviceId: deviceId, serviceUUID: serviceUUID, charUUID: charUUID,
                    dataBase64: dataBase64, callback: callback
                )
            }
        case "subscribeToCharacteristic":
            guard let deviceId = args[safe: 0] as? String,
                  let serviceUUID = args[safe: 1] as? String,
                  let charUUID = args[safe: 2] as? String else {
                callback(nil, "BluetoothModule: missing args for subscribeToCharacteristic"); return
            }
            DispatchQueue.main.async {
                BLEManager.shared.subscribeToCharacteristic(
                    deviceId: deviceId, serviceUUID: serviceUUID, charUUID: charUUID,
                    bridge: weakBridge, callback: callback
                )
            }
        case "unsubscribeFromCharacteristic":
            guard let deviceId = args[safe: 0] as? String,
                  let serviceUUID = args[safe: 1] as? String,
                  let charUUID = args[safe: 2] as? String else {
                callback(nil, "BluetoothModule: missing args for unsubscribeFromCharacteristic"); return
            }
            DispatchQueue.main.async {
                BLEManager.shared.unsubscribeFromCharacteristic(
                    deviceId: deviceId, serviceUUID: serviceUUID, charUUID: charUUID, callback: callback
                )
            }
        case "getState":
            DispatchQueue.main.async {
                callback(BLEManager.shared.getState(), nil)
            }
        default:
            callback(nil, "BluetoothModule: Unknown method '\(method)'")
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}

// MARK: - Safe array subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - BLE Manager

@MainActor
private final class BLEManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BLEManager()

    private var centralManager: CBCentralManager?
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    private var connectedPeripherals: [String: CBPeripheral] = [:]

    private struct WeakBridge { weak var bridge: NativeBridge? }
    private var scanBridge: WeakBridge?
    private var connectCallbacks: [String: (Any?, String?) -> Void] = [:]
    private var readCallbacks: [String: (Any?, String?) -> Void] = [:]
    private var writeCallbacks: [String: (Any?, String?) -> Void] = [:]
    private var subscribeBridges: [String: WeakBridge] = [:]

    // MARK: Setup

    private func ensureManager() {
        guard centralManager == nil else { return }
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: Public interface

    func getState() -> String {
        ensureManager()
        return stateString(centralManager?.state ?? .unknown)
    }

    func startScan(serviceUUIDs: [String]?, bridge: NativeBridge?) {
        ensureManager()
        scanBridge = WeakBridge(bridge: bridge)
        let uuids = serviceUUIDs?.map { CBUUID(string: $0) }
        centralManager?.scanForPeripherals(withServices: uuids, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }

    func stopScan() {
        centralManager?.stopScan()
        scanBridge = nil
    }

    func connect(deviceId: String, bridge: NativeBridge?, callback: @escaping (Any?, String?) -> Void) {
        guard let peripheral = discoveredPeripherals[deviceId] else {
            callback(nil, "Device not found: \(deviceId)"); return
        }
        connectCallbacks[deviceId] = callback
        scanBridge = WeakBridge(bridge: bridge)
        peripheral.delegate = self
        centralManager?.connect(peripheral, options: nil)
    }

    func disconnect(deviceId: String, callback: @escaping (Any?, String?) -> Void) {
        guard let peripheral = connectedPeripherals[deviceId] else {
            callback(nil, "Device not connected: \(deviceId)"); return
        }
        centralManager?.cancelPeripheralConnection(peripheral)
        callback(nil, nil)
    }

    func readCharacteristic(deviceId: String, serviceUUID: String, charUUID: String, callback: @escaping (Any?, String?) -> Void) {
        guard let peripheral = connectedPeripherals[deviceId] else {
            callback(nil, "Device not connected: \(deviceId)"); return
        }
        guard let char = findCharacteristic(peripheral: peripheral, serviceUUID: serviceUUID, charUUID: charUUID) else {
            callback(nil, "Characteristic not found: \(charUUID)"); return
        }
        let key = "\(deviceId):\(serviceUUID):\(charUUID)"
        readCallbacks[key] = callback
        peripheral.readValue(for: char)
    }

    func writeCharacteristic(deviceId: String, serviceUUID: String, charUUID: String, dataBase64: String, callback: @escaping (Any?, String?) -> Void) {
        guard let peripheral = connectedPeripherals[deviceId] else {
            callback(nil, "Device not connected: \(deviceId)"); return
        }
        guard let char = findCharacteristic(peripheral: peripheral, serviceUUID: serviceUUID, charUUID: charUUID) else {
            callback(nil, "Characteristic not found: \(charUUID)"); return
        }
        guard let data = Data(base64Encoded: dataBase64) else {
            callback(nil, "Invalid base64 data"); return
        }
        let key = "\(deviceId):\(serviceUUID):\(charUUID)"
        writeCallbacks[key] = callback
        let writeType: CBCharacteristicWriteType = char.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(data, for: char, type: writeType)
        if writeType == .withoutResponse {
            writeCallbacks.removeValue(forKey: key)
            callback(nil, nil)
        }
    }

    func subscribeToCharacteristic(deviceId: String, serviceUUID: String, charUUID: String, bridge: NativeBridge?, callback: @escaping (Any?, String?) -> Void) {
        guard let peripheral = connectedPeripherals[deviceId] else {
            callback(nil, "Device not connected: \(deviceId)"); return
        }
        guard let char = findCharacteristic(peripheral: peripheral, serviceUUID: serviceUUID, charUUID: charUUID) else {
            callback(nil, "Characteristic not found: \(charUUID)"); return
        }
        let key = "\(deviceId):\(serviceUUID):\(charUUID)"
        subscribeBridges[key] = WeakBridge(bridge: bridge)
        peripheral.setNotifyValue(true, for: char)
        callback(nil, nil)
    }

    func unsubscribeFromCharacteristic(deviceId: String, serviceUUID: String, charUUID: String, callback: @escaping (Any?, String?) -> Void) {
        guard let peripheral = connectedPeripherals[deviceId] else {
            callback(nil, "Device not connected: \(deviceId)"); return
        }
        guard let char = findCharacteristic(peripheral: peripheral, serviceUUID: serviceUUID, charUUID: charUUID) else {
            callback(nil, "Characteristic not found: \(charUUID)"); return
        }
        let key = "\(deviceId):\(serviceUUID):\(charUUID)"
        subscribeBridges.removeValue(forKey: key)
        peripheral.setNotifyValue(false, for: char)
        callback(nil, nil)
    }

    // MARK: Helpers

    private func findCharacteristic(peripheral: CBPeripheral, serviceUUID: String, charUUID: String) -> CBCharacteristic? {
        let sUUID = CBUUID(string: serviceUUID)
        let cUUID = CBUUID(string: charUUID)
        guard let service = peripheral.services?.first(where: { $0.uuid == sUUID }) else { return nil }
        return service.characteristics?.first(where: { $0.uuid == cUUID })
    }

    private func stateString(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOn: return "poweredOn"
        case .poweredOff: return "poweredOff"
        case .unauthorized: return "unauthorized"
        case .unsupported: return "unsupported"
        case .resetting: return "resetting"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }

    private func peripheralId(_ peripheral: CBPeripheral) -> String {
        peripheral.identifier.uuidString
    }

    // MARK: CBCentralManagerDelegate

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            let state = self.stateString(central.state)
            self.scanBridge?.bridge?.dispatchGlobalEvent("ble:stateChanged", payload: ["state": state])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            let id = self.peripheralId(peripheral)
            self.discoveredPeripherals[id] = peripheral
            let payload: [String: Any] = [
                "id": id,
                "name": peripheral.name ?? "",
                "rssi": RSSI.intValue,
            ]
            self.scanBridge?.bridge?.dispatchGlobalEvent("ble:deviceFound", payload: payload)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            let id = self.peripheralId(peripheral)
            self.connectedPeripherals[id] = peripheral
            peripheral.discoverServices(nil)
            let payload: [String: Any] = ["id": id, "name": peripheral.name ?? ""]
            self.scanBridge?.bridge?.dispatchGlobalEvent("ble:connected", payload: payload)
            if let cb = self.connectCallbacks.removeValue(forKey: id) {
                cb(payload, nil)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            let id = self.peripheralId(peripheral)
            self.connectedPeripherals.removeValue(forKey: id)
            let payload: [String: Any] = ["id": id, "name": peripheral.name ?? ""]
            self.scanBridge?.bridge?.dispatchGlobalEvent("ble:disconnected", payload: payload)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            let id = self.peripheralId(peripheral)
            let msg = error?.localizedDescription ?? "Connection failed"
            if let cb = self.connectCallbacks.removeValue(forKey: id) {
                cb(nil, msg)
            }
            self.scanBridge?.bridge?.dispatchGlobalEvent("ble:error", payload: ["message": msg, "deviceId": id])
        }
    }

    // MARK: CBPeripheralDelegate

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        Task { @MainActor in
            for service in peripheral.services ?? [] {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Characteristics are now available for read/write/subscribe
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            let id = self.peripheralId(peripheral)
            let serviceUUID = characteristic.service?.uuid.uuidString ?? ""
            let charUUID = characteristic.uuid.uuidString
            let key = "\(id):\(serviceUUID):\(charUUID)"
            let valueBase64 = characteristic.value?.base64EncodedString() ?? ""

            // One-shot read callback
            if let cb = self.readCallbacks.removeValue(forKey: key) {
                if let err = error {
                    cb(nil, err.localizedDescription)
                } else {
                    cb(["value": valueBase64, "characteristicUUID": charUUID, "serviceUUID": serviceUUID], nil)
                }
            }

            // Subscription notification
            if let wb = self.subscribeBridges[key] {
                wb.bridge?.dispatchGlobalEvent("ble:characteristicChanged", payload: [
                    "deviceId": id,
                    "serviceUUID": serviceUUID,
                    "characteristicUUID": charUUID,
                    "value": valueBase64,
                ])
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            let id = self.peripheralId(peripheral)
            let serviceUUID = characteristic.service?.uuid.uuidString ?? ""
            let charUUID = characteristic.uuid.uuidString
            let key = "\(id):\(serviceUUID):\(charUUID)"
            if let cb = self.writeCallbacks.removeValue(forKey: key) {
                if let err = error {
                    cb(nil, err.localizedDescription)
                } else {
                    cb(nil, nil)
                }
            }
        }
    }
}
#endif
