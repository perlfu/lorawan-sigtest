//
//  TransponderViewController.swift
//  LoRaWAN-SigTest
//
//  Created by Carl Ritson on 10/09/2016.
//  Copyright © 2016 Carl Ritson. All rights reserved.
//

import UIKit

class TransponderViewController: UIViewController {
    let manager = DeviceManager.shared
    
    @IBOutlet
    var transponderSwitch : UISwitch!
    
    @IBOutlet
    var progressView : UIProgressView!
    
    @IBOutlet
    var locationUpperLabel : UILabel!
    
    @IBOutlet
    var locationLowerLabel : UILabel!
    
    @IBOutlet
    var geohashLabel : UILabel!
    
    @IBOutlet
    var activityView : UIActivityIndicatorView!
    
    var updateTimer : NSTimer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        manager.transponderView = self
        geohashLabel.text = ""
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        updateLocation()
        statusChanged()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if updateTimer == nil {
            updateTimer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: #selector(TransponderViewController.timedUpdate), userInfo: nil, repeats: true)
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    func timedUpdate() {
        updateLocation()
        updateProgress()
    }

    func statusChanged() {
        if let device = manager.device {
            transponderSwitch.enabled = (device.con() == 1)
        } else {
            transponderSwitch.enabled = false
        }
    }
    
    func updateLocation() {
        if let location = manager.location {
            locationUpperLabel.text = "".stringByAppendingFormat("%.5f, %.5f", location.coordinate.latitude, location.coordinate.longitude)
            locationLowerLabel.text = "".stringByAppendingFormat("%.0fm", location.horizontalAccuracy)
        } else {
            locationUpperLabel.text = "Unavailable"
            locationLowerLabel.text = ""
        }
    }
    
    func updateProgress() {
        if let transpond = manager.transpond {
            var due = (30.0 - transpond.fireDate.timeIntervalSinceNow) / 30.0
            if due > 1.0 {
                due = 1.0
            }
            progressView.progress = Float(due)
        } else {
            if transponderSwitch.on {
                transponderSwitch.setOn(false, animated: true)
                activityView.stopAnimating()
            }
            progressView.progress = 0.0
        }
    }
    
    func transponding(done : Bool, success : Bool) {
        if done {
            if success {
                
            } else {
                
            }
            geohashLabel.textColor = UIColor.lightGrayColor()
            activityView.stopAnimating()
        } else {
            geohashLabel.text = manager.geohash
            geohashLabel.textColor = UIColor.darkGrayColor()
            activityView.startAnimating()
        }
    }
    
    @IBAction
    func switchChanged() {
        if transponderSwitch.on {
            if manager.startTransponder() {
                
            } else {
                transponderSwitch.setOn(false, animated: true)
            }
        } else {
            manager.stopTransponder()
        }
    }
}
