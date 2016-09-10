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
    
    let kNone = 0
    let kPing = 1
    let kSave = 2
    let kOTA = 3
    
    var lastCMD : UInt8 = 0
    var pending = 0
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
        pending = kNone
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
        if pending == kSave {
            if complete {
                pending = kNone
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
    }
    
    func notifyPing(success : Bool) {
        if pending == kPing {
            pending = kNone
            if let deviceView = deviceView {
                dispatch_async(dispatch_get_main_queue(), {
                    deviceView.pingSent(success)
                })
            }
        }
    }
    
    func notifyOTA(success : Bool) {
        if pending == kOTA {
            pending = kNone
            if let deviceView = deviceView {
                dispatch_async(dispatch_get_main_queue(), {
                    deviceView.otaComplete(success)
                })
            }
        }
    }
    
    func performOTA() -> Bool {
        if pending == kNone {
            if let device = device {
                pending = kOTA
                device.sendOTA()
                return true
            }
        }
        return false
    }
    
    func resetRN2483() {
        if let device = device {
            clearPending()
            device.sendReset()
        }
    }
    
    func sendPing() -> Bool {
        if pending == kNone {
            if let device = device {
                pending = kPing
                device.sendPacket([0], ack: true)
                return true
            }
        }
        return false
    }
    
    func requestStatusUpdate() {
        if let device = device {
            device.queryRSSI()
        }
    }
    
    func saveConfig(devEUI : [UInt8], appEUI : [UInt8], appKey : [UInt8]) -> Bool {
        if pending == kNone {
            if let device = device {
                pending = kSave
                pendingDevEUI = devEUI
                pendingAppEUI = appEUI
                pendingAppKey = appKey
                device.setDevEUI(devEUI)
                return true
            }
        }
        return false
    }
    
    func loRaWANConnected(device : LoRaWANDevice) {
        self.device = device
    }
    
    func clearPending() {
        self.notifySave(true, progress: 0.0)
        self.notifyPing(false)
        self.notifyOTA(false)
    }
    
    func loRaWANDisconnected(device : LoRaWANDevice) {
        if device == self.device {
            self.device = nil
            
            clearPending()
            notifyStatus()
            notifyConfig()
            
            dispatch_async(dispatch_get_main_queue(), {
                // restart
                self.begin()
            })
        }
    }
    
    func loRaWANReady(device : LoRaWANDevice) {
        
    }
    
    func loRAWANLocationError(message : String) {
        log.add("DeviceManager: location error; \(message)")
        lastError = message
        notifyStatus()
    }
    
    func loRaWANError(device : LoRaWANDevice, message : String) {
        log.add("DeviceManager: error; \(message)")
        clearPending()
    }
    
    func loRaWANConfigUpdated(device : LoRaWANDevice) {
        notifyConfig()
    }
    
    func loRaWANStatusUpdated(device : LoRaWANDevice, sts: Bool) {
        if sts && pending != kNone {
            // command notification
            if pending == kSave {
                if device.sts() == device.stsNoError {
                    notifySave(true, progress: 1.0)
                } else {
                    notifySave(true, progress: 0.0)
                }
            } else if pending == kPing {
                notifyPing(true)
            } else if pending == kOTA {
                notifyOTA(true)
            }
        }
        notifyStatus()
    }
    
    func loRaWANCommandSent(device : LoRaWANDevice, command : UInt8) {
        lastCMD = command
    }
    
    func loRaWANPacketSent(device : LoRaWANDevice) {
    }
    
    func loRaWANConfigWritten(device : LoRaWANDevice, uuid : String) {
        if pending == kSave {
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
