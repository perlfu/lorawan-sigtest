//
//  LoRaWANLog.swift
//  LoRaWAN-SigTest
//
//  Created by Carl Ritson on 29/08/2016.
//  Copyright © 2016 Carl Ritson. All rights reserved.
//

import Foundation

struct LoRaWANLogMessage {
    var ts : NSDate
    var text : String
}

class LoRaWANLog {
    static let shared = LoRaWANLog()
    
    var listeners : [(LoRaWANLog, LoRaWANLogMessage) -> Void] = Array()
    var messages = [LoRaWANLogMessage]()
    var printMessages = true
    
    init() {
        messages.append(LoRaWANLogMessage(ts: NSDate(), text: "Log Started"))
    }
    
    func notify(msg : LoRaWANLogMessage) {
        for closure in listeners {
            closure(self, msg)
        }
    }
    
    func add(text : String) {
        let msg = LoRaWANLogMessage(ts: NSDate(), text: text)
        messages.append(msg)
        if printMessages {
            print(text)
        }
        notify(msg)
    }
    
    func addListener(closure : (LoRaWANLog, LoRaWANLogMessage) -> Void) {
        listeners.append(closure)
    }
    
    func messageCount() -> Int {
        return messages.count
    }
    
    func latestMessage() -> LoRaWANLogMessage {
        return messages[messages.count - 1]
    }
    
    func latestTS() -> NSDate {
        return latestMessage().ts
    }
}