//
//  FirstViewController.swift
//  LoRaWAN-SigTest
//
//  Created by Carl Ritson on 26/08/2016.
//  Copyright © 2016 Carl Ritson. All rights reserved.
//

import UIKit

class FirstViewController: UIViewController, LoRaWANDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction
    func button() {
        let locator = DeviceLocator.locator
        locator.delegate = self
        locator.findDevice()
    }

    func loRaWANConnected(device : LoRaWANDevice) {
        
    }
    
    func loRaWANDisconnected(device : LoRaWANDevice) {
        
    }
    
    func loRaWANReady(device : LoRaWANDevice) {
        //device.setAppEUI([0x70, 0xB3, 0xD5, 0x7E, 0xD0, 0x00, 0x07, 0x99])
    }
    
    func loRaWANError(device : LoRaWANDevice, message : String) {
        
    }
    
    func loRaWANConfigUpdated(device : LoRaWANDevice) {
        
    }
    
    func loRaWANStatusUpdated(device : LoRaWANDevice) {
        
    }
    
    func loRaWANCommandSent(device : LoRaWANDevice, command : UInt8) {
        
    }
    
    func loRaWANConfigWritten(device : LoRaWANDevice, uuid : String) {
        //device.sendSave()
    }
}

