//
//  DailyEnergy.swift
//  UFood
//

import Foundation
import SwiftUI

/// Aggregated calorie numbers for one day.
/// All derived values live here so views only render the result.
struct DailyEnergySummary: Equatable {
    let eatenKcal: Double
    let activeBurnedKcal: Double
    let basalBurnedKcal: Double
    let healthAccessGranted: Bool
    let healthDataAvailable: Bool
    let hasBurnedData: Bool

    init(
        eatenKcal: Double,
        activeBurnedKcal: Double?,
        basalBurnedKcal: Double?,
        healthAccessGranted: Bool,
        healthDataAvailable: Bool
    ) {
        self.eatenKcal = max(0, eatenKcal)
        self.activeBurnedKcal = max(0, activeBurnedKcal ?? 0)
        self.basalBurnedKcal = max(0, basalBurnedKcal ?? 0)
        self.healthAccessGranted = healthAccessGranted
        self.healthDataAvailable = healthDataAvailable
        self.hasBurnedData = activeBurnedKcal != nil || basalBurnedKcal != nil
    }

    var burnedKcal: Double { activeBurnedKcal + basalBurnedKcal }

    /// Eaten minus burned. Negative values mean a calorie deficit.
    var balanceKcal: Double { eatenKcal - burnedKcal }

    var isDeficit: Bool { balanceKcal < 0 }
    var isSurplus: Bool { balanceKcal > 0 }

    var eatenKcalRounded: Int { Int(eatenKcal.rounded()) }
    var burnedKcalRounded: Int { Int(burnedKcal.rounded()) }
    var activeBurnedKcalRounded: Int { Int(activeBurnedKcal.rounded()) }
    var basalBurnedKcalRounded: Int { Int(basalBurnedKcal.rounded()) }

    /// Balance always carries an explicit sign, even when it is zero.
    var balanceText: String {
        CalorieMath.signedIntegerKcal(balanceKcal)
    }

    var burnedText: String { CalorieMath.integerKcal(burnedKcal) }
    var eatenText: String { CalorieMath.integerKcal(eatenKcal) }

    /// Placeholder used when Apple Health has no data for the day.
    static let noDataPlaceholder = "—"

    /// Burned energy is unknown until Apple Health returns samples for the day.
    var burnedDisplayText: String {
        hasBurnedData ? burnedText : Self.noDataPlaceholder
    }

    /// Balance stays hidden while the burned part of the equation is unknown.
    var balanceDisplayText: String {
        hasBurnedData ? balanceText : Self.noDataPlaceholder
    }

    /// Health access is missing, unsupported, or no burned data was returned.
    var showsHealthHint: Bool {
        !healthAccessGranted || !healthDataAvailable || !hasBurnedData
    }

    var balanceColor: Color {
        guard hasBurnedData else { return .secondary }
        if isDeficit { return .green }
        if isSurplus { return .orange }
        return .primary
    }

    var accessibilityBalance: String {
        guard hasBurnedData else {
            return String(format: appString("Balance: %@"), appString("no data"))
        }
        return String(
            format: appString("Balance: %@"),
            CalorieMath.accessibilityKcalPhrase(balanceKcal, includeSign: true)
        )
    }

    var accessibilityBurned: String {
        guard hasBurnedData else {
            return String(format: appString("Burned: %@"), appString("no data"))
        }
        return String(
            format: appString("Burned: %@"),
            CalorieMath.accessibilityKcalPhrase(burnedKcal)
        )
    }

    var accessibilityEaten: String {
        String(
            format: appString("Eaten: %@"),
            CalorieMath.accessibilityKcalPhrase(eatenKcal)
        )
    }
}

enum DayDateFormatting {
    /// Example (ru): "12 ноября, четверг"
    static func longDayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.dateFormat = "d MMMM, EEEE"
        return formatter.string(from: date)
    }

    /// Short weekday used as a chart axis label. Example (ru): "чт"
    static func shortWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }

    private static var currentLocale: Locale {
        AppLanguage.resolved(
            from: UserDefaults.standard.string(forKey: AppStorageKey.language) ?? AppLanguage.system.rawValue
        ).locale
    }
}
