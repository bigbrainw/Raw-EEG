import SwiftUI
import CoreBluetooth

class BluetoothViewModel: NSObject, ObservableObject {
    private var centralManager: CBCentralManager?
    private var scanTimer: Timer?
    private(set) var peripherals: [CBPeripheral] = []
    @Published var peripheralNames: [String] = []
    @Published var selectedPeripheral: CBPeripheral?
    @Published var selectedPeripheralName: String = "Unnamed Device"
    @Published var receivedDataBuffer: [String] = []
    @Published var csvFileName: String = "ReceivedData" // Default CSV file name
    @Published var isRecording: Bool = false           // Tracks recording state

    override init() {
        super.init()
        debugLog("Initializing BluetoothViewModel...")
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func startRecording() {
        isRecording = true
        debugLog("Recording started. CSV File: \(csvFileName)")
    }

    func stopRecording() {
        isRecording = false
        debugLog("Recording stopped.")
    }

    func selectPeripheral(at index: Int) {
        debugLog("Selecting peripheral at index \(index)...")
        let peripheral = peripherals[index]
        self.selectedPeripheral = peripheral
        self.selectedPeripheralName = peripheral.name ?? "Unnamed Device"
        self.centralManager?.stopScan()
        debugLog("Selected peripheral: \(self.selectedPeripheralName)")
        self.centralManager?.connect(peripheral, options: nil)
    }

    func getCSVFilePath() -> URL? {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            debugLog("getCSVFilePath: Failed to get document directory.")
            return nil
        }
        let filePath = documentDirectory.appendingPathComponent("\(csvFileName).csv")
        debugLog("getCSVFilePath: File path is \(filePath.path)")
        return filePath
    }

    func saveDataToCSV(_ row: [String]) {
        guard let filePath = getCSVFilePath() else {
            debugLog("saveDataToCSV: Invalid file path.")
            return
        }

        let csvData = row.joined(separator: ",") + "\n"

        if !FileManager.default.fileExists(atPath: filePath.path) {
            do {
                try csvData.write(to: filePath, atomically: true, encoding: .utf8)
                debugLog("saveDataToCSV: Created and saved CSV at: \(filePath.path)")
            } catch {
                debugLog("saveDataToCSV: Error creating CSV file: \(error.localizedDescription)")
            }
        } else {
            do {
                let fileHandle = try FileHandle(forWritingTo: filePath)
                fileHandle.seekToEndOfFile()
                if let data = csvData.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
                debugLog("saveDataToCSV: Data appended to CSV: \(row)")
            } catch {
                debugLog("saveDataToCSV: Error appending to CSV file: \(error.localizedDescription)")
            }
        }
    }

    private func startScanning(duration: TimeInterval = 30.0) {
        debugLog("Starting scan for peripherals...")
        centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        scanTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.stopScanning()
        }
    }

    private func stopScanning() {
        debugLog("Stopping scan...")
        centralManager?.stopScan()
        scanTimer?.invalidate()
        scanTimer = nil
    }

    // Helper function for debugging
    func debugLog(_ message: String) {
        print("[DEBUG] \(message)")
    }
}

extension BluetoothViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            debugLog("Bluetooth is powered on. Starting scan...")
            startScanning()
        case .poweredOff:
            debugLog("Bluetooth is powered off. Please enable Bluetooth.")
            stopScanning()
        case .resetting:
            debugLog("Bluetooth is resetting. Please wait...")
            stopScanning()
        case .unauthorized:
            debugLog("Bluetooth access is unauthorized. Check app permissions.")
            stopScanning()
        case .unsupported:
            debugLog("Bluetooth is unsupported on this device.")
            stopScanning()
        case .unknown:
            debugLog("Bluetooth state is unknown.")
            stopScanning()
        @unknown default:
            debugLog("A previously unknown Bluetooth state occurred.")
            stopScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
        if let name = name, RSSI.intValue > -80 {
            if !peripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                debugLog("Found \(name) with RSSI: \(RSSI)")
                self.peripherals.append(peripheral)
                self.peripheralNames.append(name)
            } else {
                debugLog("Duplicate peripheral ignored: \(name)")
            }
        } else {
            debugLog("Ignored \(name ?? "Unnamed Device") with weak signal (RSSI: \(RSSI)).")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        debugLog("Successfully connected to \(peripheral.name ?? "Unnamed Device").")
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "Unknown error"
        debugLog("Failed to connect to \(peripheral.name ?? "Unnamed Device"). Error: \(errorMessage)")

        // Retry connection after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.centralManager?.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "Unknown error"
        debugLog("Disconnected from \(peripheral.name ?? "Unnamed Device"). Error: \(errorMessage)")

        // Optionally, attempt to reconnect
        if peripheral == self.selectedPeripheral {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.centralManager?.connect(peripheral, options: nil)
            }
        }
    }
}

extension BluetoothViewModel: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                debugLog("Discovered service: \(service)")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                debugLog("Found characteristic: \(characteristic)")

                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                    debugLog("Reading value for characteristic.")
                }

                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                    debugLog("Subscribed to notifications for characteristic.")
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            self.debugLog("Error updating value for characteristic: \(error.localizedDescription)")
            return
        }

        self.debugLog("Received value for characteristic.")

        if let value = characteristic.value, isRecording {
            if let receivedString = String(data: value, encoding: .utf8) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let timestamp = Date().formattedDate()
                    let row = [timestamp, receivedString]
                    self.saveDataToCSV(row)
                    self.debugLog("Data saved to CSV: \(row.joined(separator: ", "))")
                }
            } else {
                self.debugLog("Failed to decode received data.")
            }
        }
    }
}
