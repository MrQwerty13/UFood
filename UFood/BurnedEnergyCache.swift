//
//  BurnedEnergyCache.swift
//  UFood
//

import Foundation

/// Persists HealthKit active/basal energy for completed days so history
/// does not re-query Apple Health on every open.
struct BurnedDayEnergy: Codable, Equatable, Sendable {
    let dayStart: Date
    let activeBurnedKcal: Double
    let basalBurnedKcal: Double

    var totalBurnedKcal: Double { activeBurnedKcal + basalBurnedKcal }
}

@MainActor
final class BurnedEnergyCache {
    static let shared = BurnedEnergyCache()

    private let defaults: UserDefaults
    private var entries: [String: BurnedDayEnergy]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: AppStorageKey.burnedEnergyCache),
           let decoded = try? JSONDecoder().decode([String: BurnedDayEnergy].self, from: data) {
            entries = decoded
        } else {
            entries = [:]
        }
    }

    func energy(for dayStart: Date) -> BurnedDayEnergy? {
        entries[Self.key(for: dayStart)]
    }

    func store(_ energy: BurnedDayEnergy) {
        entries[Self.key(for: energy.dayStart)] = energy
        persist()
    }

    func store(dayStart: Date, active: Double, basal: Double) {
        store(
            BurnedDayEnergy(
                dayStart: dayStart,
                activeBurnedKcal: active,
                basalBurnedKcal: basal
            )
        )
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: AppStorageKey.burnedEnergyCache)
    }

    private static func key(for dayStart: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: dayStart)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
