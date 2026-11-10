//
//  CalorieMath.swift
//  UFood
//

import Foundation

enum CalorieMath {
    static func kcal(per100g: Int, grams: Int) -> Double {
        Double(per100g) * Double(grams) / 100.0
    }

    static func roundedKcal(per100g: Int, grams: Int) -> Int {
        Int(kcal(per100g: per100g, grams: grams).rounded())
    }

    static func totalRounded(of products: [Product]) -> Int {
        Int(products.reduce(0.0) { $0 + $1.kcal }.rounded())
    }

    static func signedKcal(_ value: Int) -> String {
        let prefix = value > 0 ? "+" : ""
        return "\(prefix)\(value) kcal"
    }
}

enum AppStorageKey {
    static let theme = ThemeStorage.key
    static let displayName = "profileDisplayName"
    static let healthConnected = "healthKitConnected"
    static let aiProvider = "preferredAIProvider"
    static let language = "appLanguage"
    static let foodPresets = "foodPresets"
}
