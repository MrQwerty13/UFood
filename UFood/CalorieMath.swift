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

    /// Whole-kcal display used by dashboards and history rows.
    static func integerKcal(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    /// Balance always carries an explicit sign, even when it is zero.
    static func signedIntegerKcal(_ value: Double) -> String {
        let magnitude = abs(Int(value.rounded()))
        let sign = value < 0 ? "−" : "+"
        return "\(sign)\(magnitude)"
    }

    static func accessibilityKcalPhrase(_ value: Double, includeSign: Bool = false) -> String {
        let rounded = Int(value.rounded())
        if includeSign {
            if rounded < 0 {
                return String(format: appString("minus %lld kilocalories"), abs(rounded))
            }
            if rounded > 0 {
                return String(format: appString("plus %lld kilocalories"), rounded)
            }
            return String(format: appString("%lld kilocalories"), 0)
        }
        return String(format: appString("%lld kilocalories"), abs(rounded))
    }
}

nonisolated enum AppStorageKey {
    nonisolated static let theme = ThemeStorage.key
    nonisolated static let displayName = "profileDisplayName"
    nonisolated static let healthConnected = "healthKitConnected"
    nonisolated static let aiProvider = "preferredAIProvider"
    nonisolated static let language = "appLanguage"
    nonisolated static let foodPresets = "foodPresets"
    nonisolated static let foodTags = "foodTags"
    nonisolated static let burnedEnergyCache = "burnedEnergyCache"
}
