//
//  DeviceManager.swift
//  LoRaWAN-SigTest
//
//  Created by Carl Ritson on 2016/09/03.
//  Copyright © 2016年 Carl Ritson. All rights reserved.
//

import UIKit
import CoreLocation

class DeviceManager : NSObject, LoRaWANDelegate, CLLocationManagerDelegate {
    static let shared = DeviceManager()
    
    let locator = DeviceLocator.shared
    let log = LoRaWANLog.shared
    
    var lm : CLLocationManager!
    var deviceView : DeviceViewController?
    var configView : ConfigViewController?
    var transponderView : TransponderViewController?
    var device : LoRaWANDevice?
    var lastError = "Not Connected"
    var running = false
    
    let kNone = 0
    let kPing = 1
    let kSave = 2
    let kOTA = 3
    
    var lastCMD : UInt8 = 0
    var locked = false
    var pending = 0
    var pendingDevEUI : [UInt8]? = nil
    var pendingAppEUI : [UInt8]? = nil
    var pendingAppKey : [UInt8]? = nil
    
    var transpond : NSTimer?
    var location : CLLocation?
    var geohash : String?
    
    func activate() {
        if !running {
            self.begin()
        }
        setupLocationServices()
    }
    
    func setupLocationServices() {
        if lm == nil {
            lm = CLLocationManager()
            lm.delegate = self
            lm.requestAlwaysAuthorization()
            lm.startUpdatingLocation()
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
        if let transponderView = transponderView {
            dispatch_async(dispatch_get_main_queue(), {
                transponderView.statusChanged()
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
    
    func notifyTransponder(done : Bool, success : Bool) {
        if let transponderView = transponderView {
            dispatch_async(dispatch_get_main_queue(), {
                transponderView.transponding(done, success: success)
            })
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
        if !locked && pending == kNone {
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
        if !locked && pending == kNone {
            if let device = device {
                pending = kPing
                log.add("DeviceManager: send ping")
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
        if !locked && pending == kNone {
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
    
    func doTranspond() {
        if let device = device {
            if let location = location {
                let hash = GeoHash(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude).string(9)
                let data = Array(hash.utf8)
                geohash = hash
                log.add("DeviceManager: send \(hash)")
                device.sendPacket(data, ack: true)
                notifyTransponder(false, success: true)
            } else {
                transpond = nil
                notifyTransponder(true, success: false)
            }
        } else {
            transpond = nil
            notifyTransponder(true, success: false)
        }
    }
    
    func transponderTimer() {
        if transpond == nil {
            return
        }
        doTranspond()
    }
    
    func startTransponder() -> Bool {
        if transpond == nil {
            locked = true
            self.transpond = NSTimer.scheduledTimerWithTimeInterval(0.0, target: self, selector: #selector(DeviceManager.transponderTimer), userInfo: nil, repeats: false)
            return true
        }
        return false
    }
    
    func stopTransponder() -> Bool {
        if transpond != nil {
            transpond?.invalidate()
            transpond = nil
            locked = false
            return true
        }
        return false
    }
    
    func loRaWANConnected(device : LoRaWANDevice) {
        self.device = device
    }
    
    func clearPending() {
        stopTransponder()
        notifySave(true, progress: 0.0)
        notifyPing(false)
        notifyOTA(false)
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
        if transpond != nil {
            dispatch_async(dispatch_get_main_queue(), {
                self.transpond = NSTimer.scheduledTimerWithTimeInterval(30.0, target: self, selector: #selector(DeviceManager.transponderTimer), userInfo: nil, repeats: false)
            })
            notifyTransponder(true, success: true)
        }
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
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        //print("didChangeAuthorizationStatus \(status)")
    }
    
    func locationManager(manager: CLLocationManager, didUpdateToLocation newLocation: CLLocation, fromLocation oldLocation: CLLocation) {
        //print("didUpdateToLocation")
        location = newLocation
    }
}
