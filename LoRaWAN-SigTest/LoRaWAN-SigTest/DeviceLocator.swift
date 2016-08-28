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
    static let locator = DeviceLocator()
    
    let kServiceUUID = CBUUID(string: "3A76BBF7-351A-4276-B4D6-C30F16944084")
    
    var manager : CBCentralManager!
    var queue : dispatch_queue_t!
    var devicePeripheral : CBPeripheral?
    var device : LoRaWANDevice?
    var searching = false
    var delegate : LoRaWANDelegate?
    
    func findDevice() {
        searching = true
        
        if manager == nil {
            print("DeviceLocator: setup central")
            queue = dispatch_queue_create("uk.co.perlfu.LoRaWAN-Locator", DISPATCH_QUEUE_SERIAL)
            manager = CBCentralManager(delegate: self, queue: queue)
        }
        
        print("DeviceLocator: findDevice initiated")
        if let device = device {
            device.disconnect()
        }
        devicePeripheral = nil
        device = nil
        manager.scanForPeripheralsWithServices([kServiceUUID], options: nil)
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        print("DeviceLocator: got \(peripheral)")
        // Validate peripheral information
        if ((peripheral.name == nil) || (peripheral.name == "")) {
            return
        }
        if peripheral.name == "LoRaWAN-SigTest" {
            print("DeviceLocator: ending search")
            devicePeripheral = peripheral
            manager.stopScan()
            searching = false
            manager.connectPeripheral(peripheral, options: nil)
        }
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print("DeviceLocator: got connection")
        if peripheral == devicePeripheral {
            device = LoRaWANDevice(peripheral: peripheral)
            device!.delegate = delegate
            device!.connect()
        } else {
            print("DeviceLocator: connected to unknown device")
        }
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("DeviceLocator: disconnect \(peripheral)")
    }
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if searching {
            if central.state == .PoweredOn {
                manager.scanForPeripheralsWithServices([kServiceUUID], options: nil)
            }
        }
        print("DeviceLocator: state update \(central.state.rawValue)")
    }
}