//
//  DeviceViewController.swift
//  LoRaWAN-SigTest
//
//  Created by Carl Ritson on 29/08/2016.
//  Copyright © 2016 Carl Ritson. All rights reserved.
//

import UIKit

class DeviceViewController: UIViewController {
    let manager = DeviceManager.shared
    let dateFormatter = NSDateFormatter()
    
    @IBOutlet
    var dateTimeLabel : UILabel!
    
    @IBOutlet
    var deviceLabel : UILabel!
    
    @IBOutlet
    var loraLabel : UILabel!
    
    @IBOutlet
    var loraStatusLabel : UILabel!
    
    @IBOutlet
    var otaButton : UIButton!
    
    @IBOutlet
    var resetButton : UIButton!
    
    @IBOutlet
    var pingButton : UIButton!
    
    @IBOutlet
    var activityIndicator : UIActivityIndicatorView!
    
    @IBOutlet
    var snrLabel : UILabel!
    
    var updateTimer : NSTimer?
    var pendingUpdate = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        manager.deviceView = self
        dateTimeLabel.text = ""
        dateFormatter.dateFormat = "HH:mm:ss.SS"
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        updateStatus()
        manager.requestStatusUpdate()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        pendingUpdate = false
        if updateTimer == nil {
            updateTimer = NSTimer.scheduledTimerWithTimeInterval(5.0, target: self, selector: #selector(DeviceViewController.timedUpdate), userInfo: nil, repeats: true)
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    func timedUpdate() {
        if !pendingUpdate {
            self.activityIndicator.stopAnimating()
            pendingUpdate = true
            manager.requestStatusUpdate()
        }
    }
    
    // assumes we are running on the main queue
    func statusChanged() {
        pendingUpdate = false
        self.activityIndicator.stopAnimating()
        self.updateStatus()
    }
    
    func pingSent() {
        let alert = UIAlertController(title: "Ping", message: "Sent", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func updateStatus() {
        let now = NSDate()
        
        dateTimeLabel.text = "Status at \(dateFormatter.stringFromDate(now))"
        
        if let device = manager.device {
            var eui = ""
            if let hwEUI = device.hwEUI() {
                for byte in hwEUI {
                    eui = eui.stringByAppendingFormat("%x%x", (byte >> 4) & 0xf, byte & 0xf)
                }
            } else {
                eui = "Unknown"
            }
            deviceLabel.text = "\(eui) @ \(device.rssi)"
            otaButton.enabled = true
            resetButton.enabled = true
            if device.con() == 1 {
                loraLabel.text = "Connected to LoRaWAN"
                pingButton.enabled = true
            } else {
                loraLabel.text = "Not connected"
                pingButton.enabled = false
            }
            loraStatusLabel.text = device.stsText[device.sts()]
            snrLabel.text = "SNR: \(device.snr())"
        } else {
            otaButton.enabled = false
            resetButton.enabled = false
            pingButton.enabled = false
            loraLabel.text = "No device"
            loraStatusLabel.text = ""
            snrLabel.text = ""
            
            if manager.locator.searching() {
                deviceLabel.text = "Searching..."
            } else {
                deviceLabel.text = manager.lastError
            }
        }
    }
    
    @IBAction
    func performOTA() {
        manager.performOTA()
    }
    
    @IBAction
    func resetRN2483() {
        manager.resetRN2483()
    }
    
    @IBAction
    func sendPing() {
        manager.sendPing()
    }
}

