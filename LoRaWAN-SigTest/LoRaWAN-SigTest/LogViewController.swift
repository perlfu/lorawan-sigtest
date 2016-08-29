//
//  LogViewController.swift
//  LoRaWAN-SigTest
//
//  Created by Carl Ritson on 29/08/2016.
//  Copyright © 2016 Carl Ritson. All rights reserved.
//

import UIKit

class LogViewController: UITableViewController {
    let log = LoRaWANLog.shared
    let dateFormatter = NSDateFormatter()
    
    var messages = [LoRaWANLogMessage]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dateFormatter.dateFormat = "HH:mm:ss.SS"
        
        self.tableView.contentInset = UIEdgeInsets(top: 20.0, left: 0.0, bottom: 0.0, right: 0.0)
        
        log.addListener {src, msg in
            self.messages.append(msg)
            
            dispatch_async(dispatch_get_main_queue(), {
                self.tableView.reloadData()
                //self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: .Automatic)
            })
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        let copy = log.messages
        self.messages = copy
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("logMessage", forIndexPath: indexPath) as! LogMessageCell
        let msg = messages[messages.count - (indexPath.row + 1)]
        
        cell.tsLabel?.text = dateFormatter.stringFromDate(msg.ts)
        cell.messageLabel?.text = msg.text

        return cell
    }
}
