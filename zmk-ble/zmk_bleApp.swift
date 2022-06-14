//
//  zmk_bleApp.swift
//  zmk-ble
//
//  Created by Gabor Hornyak on 2022. 05. 31..
//

import SwiftUI
import CoreBluetooth
import OSLog

class PeripheralDelegate : NSObject, CBPeripheralDelegate {
    private var logger: Logger = Logger();

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        logger.info("didDiscoverServices");
        let batteryService = peripheral.services?.first
        if batteryService != nil{
            logger.info("Discovered \(batteryService!.description)")
            peripheral.discoverCharacteristics([CBUUID(string: "2A19")], for: batteryService!)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        logger.info("didDiscoverCharacteristics")
        service.characteristics?.forEach({characteristics in
            logger.info("Discovered \(characteristics.description)")
            service.peripheral!.readValue(for: characteristics)
        })
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        logger.info("didUpdateValueForCharacteristic")
//        logger.info("\(characteristic.value)")
        guard let firstByte = characteristic.value?.first else {
            // handle unexpected empty data
            return
        }
        let batteryLevel = firstByte
        print("battery level:", batteryLevel)
        
    }
    
}

class DummyDelegate: NSObject, CBCentralManagerDelegate {

    private let hidServiceUuid = CBUUID(string: "1812")
    
    private var logger: Logger = Logger();
    private var peripheralDelegate: CBPeripheralDelegate = PeripheralDelegate()
    private var peripheral: CBPeripheral?
    private var zmkPeripheral: ZmkPeripheral?

    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.info("centralManagerDidUpdateState");
        logger.info("\(central.state.rawValue)");
        let peripherals = central.retrieveConnectedPeripherals(withServices: [hidServiceUuid])
        peripherals.forEach({ p in
            peripheral = p
            logger.info("\(p.identifier)")
            central.connect(p)
        })
        if (peripherals.isEmpty) {
            logger.info("scanning")
                central.scanForPeripherals(withServices: [hidServiceUuid])
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("connected to \(peripheral.description)")
        self.zmkPeripheral = ZmkPeripheral(cbPeripheral: peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("didDisconnectPeripheral")
        if self.peripheral == peripheral {
            logger.info("ZMK peripheral disconnected.")
            central.scanForPeripherals(withServices: [hidServiceUuid])
            self.peripheral = nil
            self.zmkPeripheral = nil
        }
        
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        logger.info("discovered \(peripheral)")
        central.stopScan()
        self.peripheral = peripheral
        central.connect(peripheral)
    }
    
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "1.circle", accessibilityDescription: "1")
            button.action = #selector(togglePopover)
        }
        
        self.popover = NSPopover()
        self.popover.behavior = .transient
        self.popover.contentViewController = NSHostingController(rootView: ContentView())
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                self.popover.performClose(nil)
            } else {
                self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}

@main
struct zmk_bleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate;

    private var cbManager: CBCentralManager
    private var dummyDelegate: DummyDelegate = DummyDelegate()

    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    init() {
        let log = Logger()
        log.info("Init")
        cbManager = CBCentralManager(delegate: dummyDelegate, queue: nil)

    }
}
