//
//  LoRaWANDelegate.swift
//  LoRaWAN-SigTest
//
//  Created by Carl Ritson on 28/08/2016.
//  Copyright © 2016 Carl Ritson. All rights reserved.
//

import Foundation

protocol LoRaWANDelegate {
    func loRaWANConnected(device : LoRaWANDevice) -> Void
    func loRaWANDisconnected(device : LoRaWANDevice) -> Void
    func loRaWANReady(device : LoRaWANDevice) -> Void
    func loRAWANLocationError(message : String) -> Void
    func loRaWANError(device : LoRaWANDevice, message : String) -> Void
    func loRaWANConfigUpdated(device : LoRaWANDevice) -> Void
    func loRaWANStatusUpdated(device : LoRaWANDevice) -> Void
    func loRaWANCommandSent(device : LoRaWANDevice, command : UInt8) -> Void
    func loRaWANPacketSent(device : LoRaWANDevice) -> Void
    func loRaWANConfigWritten(device : LoRaWANDevice, uuid : String) -> Void
}