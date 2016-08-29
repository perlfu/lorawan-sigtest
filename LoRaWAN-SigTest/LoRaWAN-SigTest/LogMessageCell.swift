//
//  LogMessageCell.swift
//  LoRaWAN-SigTest
//
//  Created by Carl Ritson on 29/08/2016.
//  Copyright © 2016 Carl Ritson. All rights reserved.
//

import UIKit

class LogMessageCell: UITableViewCell {

    @IBOutlet
    var tsLabel: UILabel?
    
    @IBOutlet
    var messageLabel : UILabel?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
