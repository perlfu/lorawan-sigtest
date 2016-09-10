//
//  ConfigViewController.swift
//  LoRaWAN-SigTest
//
//  Created by Carl Ritson on 2016/09/03.
//  Copyright © 2016年 Carl Ritson. All rights reserved.
//

import UIKit

class ConfigViewController: UIViewController, UITextFieldDelegate {
    let manager = DeviceManager.shared
    
    @IBOutlet
    var devEUI : UITextField!
    
    @IBOutlet
    var appEUI : UITextField!
    
    @IBOutlet
    var appKey : UITextField!
    
    @IBOutlet
    var storeButton : UIButton!
    
    @IBOutlet
    var activityIndicator : UIActivityIndicatorView!
    
    @IBOutlet
    var progressBar : UIProgressView!
    
    var firstTime = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        manager.configView = self
        firstTime = true
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        if firstTime {
            updateFields()
            firstTime = false
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // assumes we are running on the main queue
    func configChanged() {
        updateFields()
    }
    
    func configSaved(complete : Bool, progress: Float) {
        if complete {
            self.activityIndicator.stopAnimating()
            self.progressBar.hidden = true
            var message = "Complete"
            if progress != 1.0 {
                message = "Failed"
            }
            showAlert("Store to Device", message: message)
            self.storeButton.enabled = true
        } else {
            self.progressBar.progress = progress
        }
    }
    
    func updateFields() {
        if let device = manager.device {
            if let devEUI = device.devEUI() {
                self.devEUI.text = hexFormatText(hexFromData(devEUI), separatorDistance: 2, lengthLimit: 16)
            }
            if let appEUI = device.appEUI() {
                self.appEUI.text = hexFormatText(hexFromData(appEUI), separatorDistance: 2, lengthLimit: 16)
            }
            if let appKey = device.appKey() {
                self.appKey.text = hexFormatText(hexFromData(appKey), separatorDistance: 8, lengthLimit: 32)
            }
            storeButton.enabled = true
        } else {
            storeButton.enabled = false
        }
    }
    
    func hexFormatText(text : String, separatorDistance : Int, lengthLimit : Int) -> String {
        do {
            let regex = try NSRegularExpression(pattern: "[a-f0-9]", options: .CaseInsensitive)
            let src = text as NSString
            var valid = ""
            var len = 0
            
            for part in regex.matchesInString(text, options: .WithoutAnchoringBounds, range: NSRange(location: 0, length: src.length)) {
                let c = src.substringWithRange(part.range)
                if len < lengthLimit {
                    valid.appendContentsOf(c.uppercaseString)
                    len += 1
                    if len % separatorDistance == 0 {
                        valid.appendContentsOf(":")
                    }
                }
            }
            if len > 0 {
                if valid.substringFromIndex(valid.endIndex.predecessor()) == ":" {
                    valid.removeAtIndex(valid.endIndex.predecessor())
                }
            }
            return valid
        } catch {
            return text
        }
    }
    
    func hexFromData(bytes : [UInt8]) -> String {
        //let bytes = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(data.bytes), count: data.length))
        var text = ""
        for byte in bytes {
            text = text.stringByAppendingFormat("%x%x", (byte >> 4) & 0xf, byte & 0xf)
        }
        return text
    }
    
    func dataFromHex(text : String, length: Int) -> [UInt8] {
        var bytes = [UInt8]()
        do {
            let regex = try NSRegularExpression(pattern: "[a-f0-9][a-f0-9]", options: .CaseInsensitive)
            let src = text as NSString
            
            for part in regex.matchesInString(text, options: .WithoutAnchoringBounds, range: NSRange(location: 0, length: src.length)) {
                let c = src.substringWithRange(part.range)
                bytes.append(UInt8(c, radix: 16)!)
            }
        } catch {
        }
        while bytes.count < length {
            bytes.append(0)
        }
        return bytes
        //return NSData(bytes: bytes, length: bytes.count)
    }

    func textFieldDidEndEditing(textField: UITextField) {
        if let text = textField.text {
            if textField == appKey {
                textField.text = hexFormatText(text, separatorDistance: 8, lengthLimit: 32)
            } else {
                textField.text = hexFormatText(text, separatorDistance: 2, lengthLimit: 16)
            }
        }
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    @IBAction
    func store() {
        self.activityIndicator.startAnimating()
        self.progressBar.hidden = false
        self.progressBar.progress = 0.0
        let ok = manager.saveConfig(dataFromHex(self.devEUI.text!, length: 8),
                           appEUI: dataFromHex(self.appEUI.text!, length: 8),
                           appKey: dataFromHex(self.appKey.text!, length: 16))
        if !ok {
            showAlert("Store to Device", message: "Failed - device busy")
            self.activityIndicator.stopAnimating()
            self.progressBar.hidden = true
        }
    }
}
