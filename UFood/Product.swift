//
//  Product.swift
//  UFood
//
//  Created by Михаил Позур on 10.11.2026.
//

import Foundation
import SwiftData

@Model
final class Product {
    var name: String
    var kkalsPer100g: Double
    var eatenGramms: Double
    var tag: String?
    var timestamp: Date

    var kcal: Double {
        CalorieMath.kcal(per100g: kkalsPer100g, grams: eatenGramms)
    }

    var formattedKcal: String {
        CalorieMath.formatted(kcal)
    }

    init(
        name: String,
        kkalsPer100g: Double,
        eatenGramms: Double,
        tag: String? = nil,
        timestamp: Date = Date()
    ) {
        self.name = name
        self.kkalsPer100g = kkalsPer100g
        self.eatenGramms = eatenGramms
        self.tag = tag
        self.timestamp = timestamp
    }
}
