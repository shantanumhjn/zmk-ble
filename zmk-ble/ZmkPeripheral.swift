//
//  ZmkPer.swift
//  zmk-ble
//
//  Created by Gabor Hornyak on 2022. 06. 10..
//

import Foundation
import CoreBluetooth
import OSLog

struct HistoricalBatteryValue {
    let date: Date
    let central: UInt8
    let peripheral: UInt8
}

class ZmkPeripheral: NSObject, CBPeripheralDelegate, ObservableObject {
    
    // Indicates that null battery level value meaning it has not been sampled yet.
    private static let NULL_VALUE: UInt8 = 0xFF
    
    private let uuidBatteryService = CBUUID(string: "180F")
    private let uuidBatteryLevelCharacteristic = CBUUID(string: "2A19")
    
    private var cbPeripheral: CBPeripheral!
    private let logger: Logger = Logger();
    
    @Published
    var centralBatteryLevel: UInt8 = 0
    @Published
    var peripheralBatteryLevel: UInt8 = 0
    @Published
    var batteryHistory: [HistoricalBatteryValue] = []
    
    var name: String {
        return cbPeripheral.name!.description
    }
    
    init(cbPeripheral: CBPeripheral, optionalZmkPeripheral: ZmkPeripheral?) {
        super.init()
        self.cbPeripheral = cbPeripheral
        self.cbPeripheral.delegate = self;
        self.cbPeripheral.discoverServices([uuidBatteryService])
        guard let zmkPeripheral = optionalZmkPeripheral else { return }
        self.batteryHistory = zmkPeripheral.batteryHistory
        self.centralBatteryLevel = zmkPeripheral.centralBatteryLevel
        self.peripheralBatteryLevel = zmkPeripheral.peripheralBatteryLevel
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        logger.info("didDiscoverServices");
        
        peripheral.services?.forEach{service in
            if service.uuid == uuidBatteryService {
                logger.info("Found battery service \(service)")
                peripheral.discoverCharacteristics([uuidBatteryLevelCharacteristic], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        logger.info("didDiscoverCharacteristics")
        service.characteristics?.forEach{characteristic in
            logger.info("found characteristic \(characteristic)")
            peripheral.discoverDescriptors(for: characteristic)
//            peripheral.readValue(for: characteristic)
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        logger.info("didUpdateValueForCharacteristic \(characteristic)")
        
        var batteryLevel:UInt8 = characteristic.value?.first ?? 0

        if (batteryLevel == ZmkPeripheral.NULL_VALUE) {
            logger.info("got null value")
            batteryLevel = 0
        }

        logger.info("batteryLevel \(batteryLevel)")
        
        let descriptor = characteristic.descriptors?.first(where: {d in d.uuid.uuidString == CBUUIDCharacteristicUserDescriptionString})
        if descriptor != nil {
            peripheralBatteryLevel = batteryLevel
            let peripheralName: String = descriptor?.value as? String ?? "Uknown"
            logger.info("possible peripheral name \(peripheralName)")
        } else {
            centralBatteryLevel = batteryLevel
        }

        batteryHistory.append(HistoricalBatteryValue(date: Date(), central: centralBatteryLevel, peripheral: peripheralBatteryLevel))
        
        peripheral.setNotifyValue(true, for: characteristic)
    }
    
    func getUserDescription(for descriptor: CBDescriptor) -> String? {
        var result: String?
        if (descriptor.uuid.uuidString == CBUUIDCharacteristicUserDescriptionString) {
            result = descriptor.value as? String
        }
        return result
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        logger.info("didDiscoverDescriptorsFor \(characteristic)")
        
        guard let userDescriptor = characteristic.descriptors?.first( where: { d in d.uuid.uuidString == CBUUIDCharacteristicUserDescriptionString }) else {
            peripheral.readValue(for: characteristic)
            return
        }
        peripheral.readValue(for: userDescriptor)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        logger.info("didUpdateValueFor descriptor \(descriptor)")
        guard let characteristic = descriptor.characteristic else { return }
        peripheral.readValue(for: characteristic)
    }
}
