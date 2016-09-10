//
//  GeoHash.swift
//  LoRaWAN-SigTest
//
//  Created by Carl Ritson on 10/09/2016.
//  Copyright © 2016 Carl Ritson. All rights reserved.
//

import UIKit

class GeoHash {
    let base32 = "0123456789bcdefghjkmnpqrstuvwxyz"
    
    let latitude : Double
    let longitude : Double
    
    init (latitude : Double, longitude : Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    func string(precision : Int) -> String {
        let lon = longitude
        let lat = latitude
        
        var idx = 0
        var bit = 0
        var even = true
        var hash = [Character]()
        var latMin = -90.0, latMax = 90.0
        var lonMin = -180.0, lonMax = 180.0
        
        while hash.count < precision {
            if even {
                let lonMid = (lonMin + lonMax) / 2.0
                if lon > lonMid {
                    idx = idx * 2 + 1
                    lonMin = lonMid
                } else {
                    idx = idx * 2
                    lonMax = lonMid
                }
            } else {
                let latMid = (latMin + latMax) / 2.0
                if lat > latMid {
                    idx = idx * 2 + 1
                    latMin = latMid
                } else {
                    idx = idx * 2
                    latMax = latMid
                }
            }
            even = !even
            
            bit += 1
            if bit == 5 {
                let character = base32.characters[base32.characters.startIndex.advancedBy(idx)]
                hash.append(character)
                bit = 0
                idx = 0
            }
        }
        
        return String(hash)
    }
}
