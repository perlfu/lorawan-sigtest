//
//  DeviceLocator.swift
//  LoRaWAN-SigTest
//
//  Created by Carl Ritson on 26/08/2016.
//  Copyright © 2016 Carl Ritson. All rights reserved.
//

import UIKit
import CoreBluetooth

class DeviceLocator: NSObject, CBCentralManagerDelegate {
    static let shared = DeviceLocator()
    
    let kServiceUUID = CBUUID(string: "3A76BBF7-351A-4276-B4D6-C30F16944084")
    
    let log = LoRaWANLog.shared
    var manager : CBCentralManager!
    var queue : dispatch_queue_t!
    var devicePeripheral : CBPeripheral?
    var device : LoRaWANDevice?
    var _searching = false
    var delegate : LoRaWANDelegate?
    
    func searching() -> Bool {
        return (_searching && manager.state == .PoweredOn)
    }
    
    func findDevice() {
        _searching = true
        
        if manager == nil {
            log.add("DeviceLocator: setup central")
            queue = dispatch_queue_create("uk.co.perlfu.LoRaWAN-Locator", DISPATCH_QUEUE_SERIAL)
            manager = CBCentralManager(delegate: self, queue: queue)
        }
        
        log.add("DeviceLocator: findDevice initiated")
        if let device = device {
            device.disconnect()
        }
        devicePeripheral = nil
        device = nil
        manager.scanForPeripheralsWithServices([kServiceUUID], options: nil)
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        log.add("DeviceLocator: got \(peripheral)")
        // Validate peripheral information
        if ((peripheral.name == nil) || (peripheral.name == "")) {
            return
        }
        
        log.add("DeviceLocator: ending search")
        devicePeripheral = peripheral
        manager.stopScan()
        _searching = false
        manager.connectPeripheral(peripheral, options: nil)
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        log.add("DeviceLocator: got connection")
        if peripheral == devicePeripheral {
            device = LoRaWANDevice(peripheral: peripheral)
            device!.delegate = delegate
            device!.connect()
        } else {
            log.add("DeviceLocator: connected to unknown device")
        }
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        log.add("DeviceLocator: disconnect \(peripheral)")
        if peripheral == devicePeripheral {
            if let device = device {
                device.disconnect()
            }
            device = nil
            devicePeripheral = nil
        }
    }

    func centralManagerDidUpdateState(central: CBCentralManager) {
        if _searching {
            if central.state == .PoweredOn {
                central.scanForPeripheralsWithServices([kServiceUUID], options: nil)
            } else if let delegate = delegate {
                if central.state == .PoweredOff {
                    delegate.loRAWANLocationError("Bluetooth turned off")
                } else if central.state == .Unsupported {
                    delegate.loRAWANLocationError("Bluetooth not supported")
                } else if central.state == .Unauthorized {
                    delegate.loRAWANLocationError("Bluetooth access not permitted")
                }
            }
        }
        log.add("DeviceLocator: state update \(central.state.rawValue)")
    }
}