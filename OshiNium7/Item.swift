//
//  Item.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/11.
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
