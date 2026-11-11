//
//  DailyEnergy.swift
//  UFood
//

import Foundation

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
        let magnitude = abs(Int(balanceKcal.rounded()))
        let sign = balanceKcal < 0 ? "−" : "+"
        return "\(sign)\(magnitude)"
    }

    /// Health access is missing, unsupported, or no burned data was returned.
    var showsHealthHint: Bool {
        !healthAccessGranted || !healthDataAvailable || !hasBurnedData
    }
}
