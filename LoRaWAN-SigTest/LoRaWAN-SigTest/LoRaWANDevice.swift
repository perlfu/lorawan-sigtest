//
//  LoRaWANDevice.swift
//  LoRaWAN-SigTest
//
//  Created by Carl Ritson on 26/08/2016.
//  Copyright © 2016 Carl Ritson. All rights reserved.
//

import UIKit
import CoreBluetooth

class LoRaWANDevice : NSObject, CBPeripheralDelegate {
    let kServiceUUID = CBUUID(string: "3A76BBF7-351A-4276-B4D6-C30F16944084")
    let kHWEUI      = CBUUID(string: "FF01")
    let kDevEUI     = CBUUID(string: "FF02")
    let kAppEUI     = CBUUID(string: "FF03")
    let kAppKey     = CBUUID(string: "FF04")
    let kPort       = CBUUID(string: "FF05")
    let kRetries    = CBUUID(string: "FF06")
    let kCMD        = CBUUID(string: "FF00")
    let kPKT        = CBUUID(string: "FF10")
    let kCON        = CBUUID(string: "FF20")
    let kSTS        = CBUUID(string: "FF21")
    let kSNR        = CBUUID(string: "FF22")
    
    let cmdNone         : UInt8 = 0x00
    let cmdMask         : UInt8 = 0xf0
    let cmdOTA          : UInt8 = 0x10
    let cmdSend         : UInt8 = 0x20
    let cmdSendAck      : UInt8 = 0x21
    let cmdSendEmpty    : UInt8 = 0x22
    let cmdSendEmptyAck : UInt8 = 0x23
    let cmdReset        : UInt8 = 0x40
    let cmdSave         : UInt8 = 0x50
    
    let stsNone              : UInt8 = 0
    let stsOTASuccess        : UInt8 = 1
    let stsOTAFailed         : UInt8 = 2
    let stsNoError           : UInt8 = 3
    let stsNoResponse        : UInt8 = 4
    let stsTimeout           : UInt8 = 5
    let stsPayloadSizeError  : UInt8 = 6
    let stsInternalError     : UInt8 = 7
    let stsBusy              : UInt8 = 8
    let stsNetworkFatalError : UInt8 = 9
    let stsNotConnected      : UInt8 = 10
    let stsNoAcknowledgment  : UInt8 = 11
    let stsUnknown           : UInt8 = 127
    let stsText : [UInt8: String] = [
        0 : "No status",
        1 : "OTA success",
        2 : "OTA failed",
        3 : "No error",
        4 : "No response",
        5 : "Timeout",
        6 : "Payload size error",
        7 : "Internal error",
        8 : "Busy",
        9 : "Network fatal error",
        10: "Not connected",
        11: "No acknowledment",
        127: "Unknown status"
    ]
    
    let log = LoRaWANLog.shared
    
    var devicePeripheral : CBPeripheral!
    var delegate : LoRaWANDelegate?
    var _ready = false
    var state = [String : NSData]()
    var configVar = [String : Bool]()
    var statusVar = [String : Bool]()
    var pendingCMD : UInt8? = nil
    var pendingPacket : [UInt8]? = nil
    var rssi : NSNumber = 0.0
    
    var cHWEUI : CBCharacteristic!
    var cDevEUI : CBCharacteristic!
    var cAppEUI : CBCharacteristic!
    var cAppKey : CBCharacteristic!
    var cPort : CBCharacteristic!
    var cRetries : CBCharacteristic!
    var cCMD : CBCharacteristic!
    var cPKT : CBCharacteristic!
    var cCON : CBCharacteristic!
    var cSTS : CBCharacteristic!
    var cSNR : CBCharacteristic!
    
    init(peripheral : CBPeripheral) {
        devicePeripheral = peripheral
        configVar[kHWEUI.UUIDString] = true
        configVar[kDevEUI.UUIDString] = true
        configVar[kAppEUI.UUIDString] = true
        configVar[kAppKey.UUIDString] = true
        configVar[kPort.UUIDString] = true
        configVar[kRetries.UUIDString] = true
        statusVar[kCON.UUIDString] = true
        statusVar[kSTS.UUIDString] = true
        statusVar[kSNR.UUIDString] = true
    }
    
    func connect() {
        if let delegate = delegate {
            delegate.loRaWANConnected(self)
        }
        devicePeripheral.delegate = self
        devicePeripheral.discoverServices([kServiceUUID])
    }
    
    func disconnect() {
        if let delegate = delegate {
            delegate.loRaWANDisconnected(self)
        }
        devicePeripheral = nil
    }
    
    func ready() -> Bool {
        if !_ready {
            if (devicePeripheral != nil) &&
                    (cHWEUI != nil) && (cDevEUI != nil) &&
                    (cAppEUI != nil) && (cAppKey != nil) &&
                    (cPort != nil) && (cRetries != nil) &&
                    (cCMD != nil) && (cPKT != nil) &&
                    (cCON != nil) && (cSTS != nil) &&
                (cSTS != nil) && (cSNR != nil) {
                _ready = true
            }
        }
        return _ready
    }
    
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        log.add("LoRaWANDevice: didDiscoverServices")
        if error != nil {
            return
        }
        for service in peripheral.services! {
            if service.UUID == kServiceUUID {
                peripheral.discoverCharacteristics([kHWEUI, kDevEUI, kAppEUI, kAppKey, kPort, kRetries, kCMD, kPKT, kCON, kSTS, kSNR], forService: service)
            }
        }
        
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        log.add("LoRaWANDevice: didDiscoverCharacteristicsForService")
        if error != nil {
            return
        }
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                switch (characteristic.UUID) {
                case kHWEUI: cHWEUI = characteristic; break;
                case kDevEUI: cDevEUI = characteristic; break;
                case kAppEUI: cAppEUI = characteristic; break;
                case kAppKey: cAppKey = characteristic; break;
                case kPort: cPort = characteristic; break;
                case kRetries: cRetries = characteristic; break;
                case kCMD: cCMD = characteristic; break;
                case kPKT: cPKT = characteristic; break;
                case kCON: cCON = characteristic; break;
                case kSTS: cSTS = characteristic; break;
                case kSNR: cSNR = characteristic; break;
                default:
                    break;
                }
            }
        }
        
        let ready = self.ready()
        
        log.add("LoRaWANDevice: ready=\(ready)")
        
        if ready {
            self.configureDevice()
            devicePeripheral.readValueForCharacteristic(cSTS)
            //self.queryStatus(true)
            self.queryConfig()
        }
        
        if let delegate = delegate {
            if ready {
                delegate.loRaWANReady(self)
            } else {
                delegate.loRaWANError(self, message: "incompatible device")
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        log.add("LoRaWANDevice: notify \(characteristic.UUID)")
    }
    
    func peripheral(peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: NSError?) {
        log.add("LoRaWANDevice: rssi \(RSSI)")
        rssi = RSSI
        if let delegate = delegate {
            delegate.loRaWANStatusUpdated(self, sts: false)
        }
    }

    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        log.add("LoRaWANDevice: update \(characteristic.UUID)")
        if let value = characteristic.value {
            log.add("LoRaWANDevice: update data = \(value)")
            state[characteristic.UUID.UUIDString] = value
            
            if characteristic.UUID == kSTS {
                // this is a notification from device; follow up with reads on other fields
                queryStatus(false)
            }
            
            if let delegate = delegate {
                if statusVar[characteristic.UUID.UUIDString] != nil {
                    delegate.loRaWANStatusUpdated(self, sts: characteristic.UUID == kSTS)
                }
                if configVar[characteristic.UUID.UUIDString] != nil {
                    delegate.loRaWANConfigUpdated(self)
                }
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        log.add("LoRaWANDevice: didWriteValueForCharacteristic \(characteristic.UUID), error: \(error)")
        if error == nil {
            if characteristic.UUID == kCMD {
                // command write successful
                if let delegate = delegate {
                    let cmd = pendingCMD
                    pendingCMD = nil
                    if let cmd = cmd {
                        if (cmd & cmdMask) == cmdSend {
                            delegate.loRaWANPacketSent(self)
                        } else {
                            delegate.loRaWANCommandSent(self, command: cmd)
                        }
                    }
                }
                
            } else if characteristic.UUID == kPKT {
                // packet write successful, follow up with cmd write
                if let cmd = pendingCMD {
                    self.writeUInt8(cCMD, data: cmd)
                }
                pendingPacket = nil
            } else {
                // config update successful
                if let delegate = delegate {
                    if let value = characteristic.value {
                        state[characteristic.UUID.UUIDString] = value
                    }
                    delegate.loRaWANConfigWritten(self, uuid: characteristic.UUID.UUIDString)
                }
            }
        } else {
            // clear pending command
            pendingPacket = nil
            pendingCMD = nil
            // notify delegate
            if let delegate = delegate {
                delegate.loRaWANError(self, message: "device write failed: \(error)")
            }
        }
    }
    
    func configureDevice() {
        devicePeripheral.setNotifyValue(true, forCharacteristic: cSTS)
    }
    
    func queryRSSI() {
        devicePeripheral.readRSSI()
    }
    
    func queryStatus(withSTS: Bool) {
        if self.ready() {
            devicePeripheral.readRSSI()
            if withSTS {
                devicePeripheral.readValueForCharacteristic(cSTS)
            }
            devicePeripheral.readValueForCharacteristic(cCON)
            devicePeripheral.readValueForCharacteristic(cSNR)
        }
    }
    
    func queryConfig() {
        if self.ready() {
            devicePeripheral.readValueForCharacteristic(cHWEUI)
            devicePeripheral.readValueForCharacteristic(cDevEUI)
            devicePeripheral.readValueForCharacteristic(cAppEUI)
            devicePeripheral.readValueForCharacteristic(cAppKey)
            devicePeripheral.readValueForCharacteristic(cPort)
            devicePeripheral.readValueForCharacteristic(cRetries)
        }
    }
    
    func readNbyte(key: String, length: Int) -> [UInt8]? {
        if let value = state[key] {
            if value.length == length {
                var bytes = [UInt8](count: length, repeatedValue: 0)
                value.getBytes(&bytes, length: length)
                return bytes
            }
        }
        return nil
    }
    
    func writeNByte(characteristic : CBCharacteristic, data : [UInt8]) {
        let value = NSData(bytes: data, length: data.count)
        devicePeripheral.writeValue(value, forCharacteristic: characteristic, type: .WithResponse)
    }
    
    func readUInt8(key : String) -> UInt8? {
        if let value = state[key] {
            if value.length == 1 {
                var bytes = [UInt8](count: 1, repeatedValue: 0)
                value.getBytes(&bytes, length: 1)
                return bytes[0]
            }
        }
        return nil
    }
    
    func writeUInt8(characteristic : CBCharacteristic, data : UInt8) {
        let value = NSData(bytes: [data], length: 1)
        devicePeripheral.writeValue(value, forCharacteristic: characteristic, type: .WithResponse)
    }
    
    func hwEUI() -> [UInt8]? {
        return self.readNbyte(kHWEUI.UUIDString, length: 8)
    }
    
    func devEUI() -> [UInt8]? {
        return self.readNbyte(kDevEUI.UUIDString, length: 8)
    }
    func setDevEUI(data : [UInt8]) {
        if data.count == 8 {
            self.writeNByte(cDevEUI, data: data)
        }
    }
    
    func appEUI() -> [UInt8]? {
        return self.readNbyte(kAppEUI.UUIDString, length: 8)
    }
    func setAppEUI(data : [UInt8]) {
        if data.count == 8 {
            self.writeNByte(cAppEUI, data: data)
        }
    }
    
    func appKey() -> [UInt8]? {
        return self.readNbyte(kAppKey.UUIDString, length: 16)
    }
    func setAppKey(data : [UInt8]) {
        if data.count == 16 {
            self.writeNByte(cAppKey, data: data)
        }
    }
    
    func port() -> UInt8? {
        return self.readUInt8(kPort.UUIDString)
    }
    func setPort(data : UInt8) {
        self.writeUInt8(cPort, data: data)
    }
    
    func retries() -> UInt8? {
        return self.readUInt8(kRetries.UUIDString)
    }
    func setRetries(data : UInt8) {
        self.writeUInt8(cRetries, data: data)
    }
    
    func con() -> UInt8 {
        if let val = self.readUInt8(kCON.UUIDString) {
            return val
        } else {
            return 0
        }
    }
    
    func sts() -> UInt8 {
        if let val = self.readUInt8(kSTS.UUIDString) {
            return val
        } else {
            return 0
        }
    }
    
    func snr() -> Int8 {
        if let value = state[kSNR.UUIDString] {
            if let str = NSString(data: value, encoding: NSASCIIStringEncoding) {
                //print("raw snr: \(str)")
                return Int8(truncatingBitPattern: str.intValue)
            }
        }
        return -128
    }
    
    func sendCommand(cmd : UInt8) -> Bool {
        if pendingCMD != nil {
            return false
        }
        pendingCMD = cmd
        self.writeUInt8(cCMD, data: cmd)
        return true
    }
    
    func sendOTA() -> Bool {
        return self.sendCommand(cmdOTA)
    }
    
    func sendReset() -> Bool {
        return self.sendCommand(cmdReset)
    }
    
    func sendSave() -> Bool {
        return self.sendCommand(cmdSave)
    }
    
    func sendPacket(data : [UInt8], ack : Bool) -> Bool {
        if pendingCMD != nil {
            return false
        }
        
        var cmd = cmdSend
        if ack {
            if data.count > 0 {
                cmd = cmdSendAck
            } else {
                cmd = cmdSendEmptyAck
            }
        } else {
            if data.count == 0 {
                cmd = cmdSendEmpty
            }
        }
        pendingCMD = cmd
        if data.count > 0 {
            pendingPacket = data
            self.writeNByte(cPKT, data: data)
        } else {
            self.writeUInt8(cCMD, data: cmd)
        }
        
        return true
    }
}
