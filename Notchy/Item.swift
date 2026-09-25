//
//  Item.swift
//  Notchy
//
//  Created by Nilkanth Desai on 25/09/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
