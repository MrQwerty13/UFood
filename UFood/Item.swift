//
//  Item.swift
//  UFood
//
//  Created by Михаил Позур on 10.11.2026.
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
