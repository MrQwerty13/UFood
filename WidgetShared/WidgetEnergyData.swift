//
//  WidgetEnergyData.swift
//  UFood
//

import Foundation
import WidgetKit
import os

struct WidgetEnergyData: Codable, Equatable {
    let dayStart: Date
    let eatenKcal: Double
    let burnedKcal: Double?
    let themeID: String

    init(dayStart: Date, eatenKcal: Double, burnedKcal: Double?, themeID: String) {
        self.dayStart = dayStart
        self.eatenKcal = eatenKcal
        self.burnedKcal = burnedKcal
        self.themeID = themeID
    }

    var balanceKcal: Double? {
        burnedKcal.map { eatenKcal - $0 }
    }
}

enum WidgetEnergyDataStore {
    static let appGroupIdentifier = "group.MrQwerty13.UFood"
    static let widgetKind = "UFoodCalorieBalanceWidget"
    private static let dataKey = "dailyWidgetEnergy"
    private static let logger = Logger(subsystem: "MrQwerty13.UFood", category: "widget")

    static func save(_ value: WidgetEnergyData) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            logger.error("Could not access the app group shared with the widget.")
            return
        }

        do {
            defaults.set(try JSONEncoder().encode(value), forKey: dataKey)
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        } catch {
            logger.error("Could not save widget energy data: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func load(for date: Date = .now) -> WidgetEnergyData? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            logger.error("Could not access the app group shared with the widget.")
            return nil
        }
        guard let data = defaults.data(forKey: dataKey) else { return nil }

        do {
            let value = try JSONDecoder().decode(WidgetEnergyData.self, from: data)
            guard Calendar.current.isDate(value.dayStart, inSameDayAs: date) else { return nil }
            return value
        } catch {
            logger.error("Could not read widget energy data: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
