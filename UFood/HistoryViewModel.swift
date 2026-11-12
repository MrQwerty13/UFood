//
//  HistoryViewModel.swift
//  UFood
//

import Foundation
import Observation
import SwiftData

struct HistoryDayItem: Identifiable, Equatable {
    let dayStart: Date
    let summary: DailyEnergySummary
    let hasFood: Bool

    var id: Date { dayStart }

    var title: String {
        DayDateFormatting.longDayTitle(dayStart)
    }
}

struct BalanceChartPoint: Identifiable, Equatable {
    let dayStart: Date
    let balanceKcal: Double
    let hasData: Bool

    var id: Date { dayStart }

    var label: String {
        DayDateFormatting.shortWeekday(dayStart)
    }
}

@MainActor
@Observable
final class HistoryViewModel {
    private let calendar: Calendar
    private let healthLookbackDays = 90

    private(set) var days: [HistoryDayItem] = []
    private(set) var chartPoints: [BalanceChartPoint] = []
    private(set) var averageBalance7Days: Double?
    private(set) var isLoading = false
    private(set) var healthAccessGranted = false

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Rebuilds history from local food entries and (optionally) HealthKit.
    /// Today is intentionally excluded so midnight rollover moves it into history automatically.
    func refresh(
        products: [Product],
        todayStart: Date,
        healthKit: HealthKitManager
    ) async {
        isLoading = true
        defer { isLoading = false }

        healthAccessGranted = healthKit.isAuthorized && healthKit.isAvailable

        let normalizedToday = calendar.startOfDay(for: todayStart)
        let productsByDay = Dictionary(grouping: products) { product in
            calendar.startOfDay(for: product.timestamp)
        }
        .filter { $0.key < normalizedToday }

        var candidateDays = Set(productsByDay.keys)

        if healthAccessGranted {
            for offset in 1...healthLookbackDays {
                if let day = calendar.date(byAdding: .day, value: -offset, to: normalizedToday) {
                    candidateDays.insert(calendar.startOfDay(for: day))
                }
            }
        }

        let sortedCandidates = candidateDays.sorted(by: >)
        let burnedByDay = await healthKit.preloadBurnedEnergy(forDayStarts: Array(sortedCandidates))

        var builtDays: [HistoryDayItem] = []
        builtDays.reserveCapacity(sortedCandidates.count)

        for dayStart in sortedCandidates {
            let dayProducts = productsByDay[dayStart] ?? []
            let eaten = CalorieMath.total(of: dayProducts)
            let burned = burnedByDay[dayStart]
            let hasFood = !dayProducts.isEmpty
            let hasBurned = burned != nil

            guard hasFood || hasBurned else { continue }

            let summary = DailyEnergySummary(
                eatenKcal: eaten,
                activeBurnedKcal: burned.map(\.activeBurnedKcal),
                basalBurnedKcal: burned.map(\.basalBurnedKcal),
                healthAccessGranted: healthAccessGranted,
                healthDataAvailable: healthKit.isAvailable
            )

            builtDays.append(
                HistoryDayItem(
                    dayStart: dayStart,
                    summary: summary,
                    hasFood: hasFood
                )
            )
        }

        days = builtDays
        rebuildSevenDayStats(todayStart: normalizedToday, days: builtDays)
    }

    func summary(
        for dayStart: Date,
        products: [Product],
        healthKit: HealthKitManager
    ) async -> DailyEnergySummary {
        let normalized = calendar.startOfDay(for: dayStart)
        let eaten = CalorieMath.total(of: products)
        let burned = await healthKit.burnedEnergy(forDayStarting: normalized)
        return DailyEnergySummary(
            eatenKcal: eaten,
            activeBurnedKcal: burned.map(\.activeBurnedKcal),
            basalBurnedKcal: burned.map(\.basalBurnedKcal),
            healthAccessGranted: healthKit.isAuthorized && healthKit.isAvailable,
            healthDataAvailable: healthKit.isAvailable
        )
    }

    private func rebuildSevenDayStats(todayStart: Date, days: [HistoryDayItem]) {
        let dayLookup = Dictionary(uniqueKeysWithValues: days.map { ($0.dayStart, $0) })
        var points: [BalanceChartPoint] = []
        var balances: [Double] = []

        for offset in (1...7).reversed() {
            guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: todayStart) else {
                continue
            }
            let normalized = calendar.startOfDay(for: dayStart)
            if let item = dayLookup[normalized], item.summary.hasBurnedData {
                points.append(
                    BalanceChartPoint(
                        dayStart: normalized,
                        balanceKcal: item.summary.balanceKcal,
                        hasData: true
                    )
                )
                balances.append(item.summary.balanceKcal)
            } else {
                points.append(
                    BalanceChartPoint(
                        dayStart: normalized,
                        balanceKcal: 0,
                        hasData: false
                    )
                )
            }
        }

        chartPoints = points
        averageBalance7Days = balances.isEmpty
            ? nil
            : balances.reduce(0, +) / Double(balances.count)
    }
}

/// Stable fingerprint of the food entries, used to detect real changes
/// (edit or delete) and to trigger a recalculation of the balance.
enum ProductFingerprint {
    static func value(for products: [Product]) -> String {
        products
            .map { "\($0.persistentModelID)-\(CalorieMath.formatted($0.kcal))" }
            .joined(separator: ";")
    }
}
