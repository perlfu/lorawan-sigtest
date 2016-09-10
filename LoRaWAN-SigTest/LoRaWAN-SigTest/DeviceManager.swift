//
//  DeviceManager.swift
//  LoRaWAN-SigTest
//
//  Created by Carl Ritson on 2016/09/03.
//  Copyright © 2016年 Carl Ritson. All rights reserved.
//

import UIKit

class DeviceManager : LoRaWANDelegate {
    static let shared = DeviceManager()
    
    let locator = DeviceLocator.shared
    let log = LoRaWANLog.shared
    
    var deviceView : DeviceViewController?
    var configView : ConfigViewController?
    var device : LoRaWANDevice?
    var lastError = "Not Connected"
    var running = false
    
    var pendingPing = false
    
    var pendingSave = false
    var pendingDevEUI : [UInt8]? = nil
    var pendingAppEUI : [UInt8]? = nil
    var pendingAppKey : [UInt8]? = nil
    
    func activate() {
        if !running {
            self.begin()
        }
    }
    
    func begin() {
        running = true
        locator.delegate = self
        locator.findDevice()
    }
    
    func notifyStatus() {
        if let deviceView = deviceView {
            dispatch_async(dispatch_get_main_queue(), {
                deviceView.statusChanged()
            })
        }
    }
    
    func notifyConfig() {
        if let configView = configView {
            dispatch_async(dispatch_get_main_queue(), {
                configView.configChanged()
            })
        }
    }
    
    func notifySave(complete : Bool, progress : Float) {
        if complete {
            pendingSave = false
            pendingDevEUI = nil
            pendingAppEUI = nil
            pendingAppKey = nil
        }
        if let configView = configView {
            dispatch_async(dispatch_get_main_queue(), {
                configView.configSaved(complete, progress: progress)
            })
        }
    }
    
    func notifyPing() {
        pendingPing = false
        if let deviceView = deviceView {
            dispatch_async(dispatch_get_main_queue(), {
                deviceView.pingSent()
            })
        }
    }
    
    func performOTA() {
        if let device = device {
            device.sendOTA()
        }
    }
    
    func resetRN2483() {
        if let device = device {
            device.sendReset()
        }
    }
    
    func sendPing() {
        if let device = device {
            pendingPing = true
            device.sendPacket([0], ack: true)
        }
    }
    
    func requestStatusUpdate() {
        if let device = device {
            device.queryRSSI()
            //device.queryStatus()
        }
    }
    
    func saveConfig(devEUI : [UInt8], appEUI : [UInt8], appKey : [UInt8]) {
        if !pendingSave {
            if let device = device {
                pendingDevEUI = devEUI
                pendingAppEUI = appEUI
                pendingAppKey = appKey
                pendingSave = true
                device.setDevEUI(devEUI)
            } else {
                notifySave(true, progress: 0.0)
            }
        }
    }
    
    func loRaWANConnected(device : LoRaWANDevice) {
        self.device = device
    }
    
    func loRaWANDisconnected(device : LoRaWANDevice) {
        if device == self.device {
            self.device = nil
            self.notifyStatus()
            if pendingSave {
                self.notifySave(true, progress: 0.0)
            }
            self.notifyConfig()
            
            dispatch_async(dispatch_get_main_queue(), {
                // restart
                self.begin()
            })
        }
    }
    
    func loRaWANReady(device : LoRaWANDevice) {
        //device.setAppEUI([0x70, 0xB3, 0xD5, 0x7E, 0xD0, 0x00, 0x07, 0x99])
    }
    
    func loRAWANLocationError(message : String) {
        log.add("DeviceManager: location error; \(message)")
        lastError = message
        notifyStatus()
    }
    
    func loRaWANError(device : LoRaWANDevice, message : String) {
        if pendingSave {
            notifySave(true, progress: 0.0)
        }
        if pendingPing {
            pendingPing = false
        }
    }
    
    func loRaWANConfigUpdated(device : LoRaWANDevice) {
        notifyConfig()
    }
    
    func loRaWANStatusUpdated(device : LoRaWANDevice) {
        notifyStatus()
    }
    
    func loRaWANCommandSent(device : LoRaWANDevice, command : UInt8) {
        if command == device.cmdSave {
            if pendingSave {
                notifySave(true, progress: 1.0)
            }
        }
    }
    
    func loRaWANPacketSent(device : LoRaWANDevice) {
        if pendingPing {
            notifyPing()
        }
    }
    
    func loRaWANConfigWritten(device : LoRaWANDevice, uuid : String) {
        if pendingSave {
            if uuid == device.kDevEUI.UUIDString {
                notifySave(false, progress: 0.25)
                device.setAppEUI(pendingAppEUI!)
            }
            if uuid == device.kAppEUI.UUIDString {
                notifySave(false, progress: 0.5)
                device.setAppKey(pendingAppKey!)
            }
            if uuid == device.kAppKey.UUIDString {
                notifySave(false, progress: 0.75)
                device.sendSave()
            }
        }
    }
}
