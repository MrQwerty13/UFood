//
//  CalorieMath.swift
//  UFood
//

import Foundation

enum CalorieMath {
    static func kcal(per100g: Double, grams: Double) -> Double {
        per100g * grams / 100.0
    }

    static func total(of products: [Product]) -> Double {
        products.reduce(0.0) { $0 + $1.kcal }
    }

    /// Parses user input using either a comma or a dot as the decimal separator.
    static func parseDecimal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard normalized.filter({ $0 == "." }).count <= 1,
              let value = Double(normalized),
              value.isFinite
        else { return nil }

        return value
    }

    /// Formats a value with up to one decimal place, omitting a trailing `.0`.
    static func formatted(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        let displayValue = rounded == 0 ? 0 : rounded
        let language = AppLanguage.resolved(
            from: UserDefaults.standard.string(forKey: AppStorageKey.language) ?? AppLanguage.system.rawValue
        )
        return displayValue.formatted(
            .number.locale(language.locale).precision(.fractionLength(0...1))
        )
    }

    static func signed(_ value: Double) -> String {
        let prefix = value > 0 ? "+" : ""
        return "\(prefix)\(formatted(value))"
    }
}

enum AppStorageKey {
    static let theme = ThemeStorage.key
    static let displayName = "profileDisplayName"
    static let healthConnected = "healthKitConnected"
    static let aiProvider = "preferredAIProvider"
    static let language = "appLanguage"
    static let foodPresets = "foodPresets"
    static let foodTags = "foodTags"
}
