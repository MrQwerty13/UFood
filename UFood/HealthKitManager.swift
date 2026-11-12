//
//  HealthKitManager.swift
//  UFood
//

import Foundation
import HealthKit
import os

@MainActor
@Observable
final class HealthKitManager {
    private let store = HKHealthStore()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "UFood", category: "health")
    private let burnedCache: BurnedEnergyCache
    var isAuthorized: Bool {
        didSet { UserDefaults.standard.set(isAuthorized, forKey: AppStorageKey.healthConnected) }
    }
    var activeBurnedKcal: Double?
    var restingBurnedKcal: Double?
    var statusMessage: String?
    var isLoading = false
    private var observerQueries: [HKObserverQuery] = []
    private var isObservingHealthData = false

    init(burnedCache: BurnedEnergyCache? = nil) {
        self.burnedCache = burnedCache ?? BurnedEnergyCache.shared
        isAuthorized = UserDefaults.standard.bool(forKey: AppStorageKey.healthConnected)
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var totalBurnedKcal: Double? {
        guard isAuthorized else { return nil }
        guard activeBurnedKcal != nil || restingBurnedKcal != nil else { return nil }
        return (activeBurnedKcal ?? 0) + (restingBurnedKcal ?? 0)
    }

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
        ]
    }

    private var writeTypes: Set<HKSampleType> {
        [
            HKQuantityType(.dietaryEnergyConsumed),
        ]
    }

    func requestAuthorization() async {
        guard isAvailable else {
            statusMessage = appString("Apple Health is not available on this device.")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            statusMessage = nil
            startObservingHealthData()
            await refreshToday()
        } catch {
            logger.error("Could not connect to Apple Health: \(error.localizedDescription, privacy: .public)")
            statusMessage = appString("Could not connect to Apple Health.")
        }
    }

    func refreshIfNeeded() async {
        guard isAuthorized else { return }
        startObservingHealthData()
        await refreshToday()
    }

    func refreshToday() async {
        guard isAvailable else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            async let active = sumKcal(for: .activeEnergyBurned, from: startOfDay, to: now)
            async let resting = sumKcal(for: .basalEnergyBurned, from: startOfDay, to: now)
            activeBurnedKcal = try await active
            restingBurnedKcal = try await resting
            statusMessage = nil
        } catch {
            logger.error("Could not load Apple Health data: \(error.localizedDescription, privacy: .public)")
            statusMessage = appString("Could not load Apple Health data.")
        }
    }

    /// Returns cached or freshly queried active/basal energy for a completed day.
    /// `nil` means Apple Health had no samples for that day.
    func burnedEnergy(forDayStarting dayStart: Date, forceRefresh: Bool = false) async -> BurnedDayEnergy? {
        guard isAvailable, isAuthorized else { return nil }

        let normalizedStart = Calendar.current.startOfDay(for: dayStart)
        if !forceRefresh, let cached = burnedCache.energy(for: normalizedStart) {
            return cached
        }

        guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: normalizedStart) else {
            return nil
        }

        do {
            async let active = sumKcalOptional(for: .activeEnergyBurned, from: normalizedStart, to: dayEnd)
            async let basal = sumKcalOptional(for: .basalEnergyBurned, from: normalizedStart, to: dayEnd)
            let activeValue = try await active
            let basalValue = try await basal

            guard activeValue != nil || basalValue != nil else { return nil }

            let energy = BurnedDayEnergy(
                dayStart: normalizedStart,
                activeBurnedKcal: activeValue ?? 0,
                basalBurnedKcal: basalValue ?? 0
            )
            burnedCache.store(energy)
            return energy
        } catch {
            logger.error(
                "Could not load Apple Health data for day: \(error.localizedDescription, privacy: .public)"
            )
            return burnedCache.energy(for: normalizedStart)
        }
    }

    /// Prefetches burned energy for many completed days, using cache when possible.
    func preloadBurnedEnergy(forDayStarts dayStarts: [Date]) async -> [Date: BurnedDayEnergy] {
        var result: [Date: BurnedDayEnergy] = [:]
        guard isAvailable, isAuthorized else { return result }

        let uniqueStarts = Array(
            Set(dayStarts.map { Calendar.current.startOfDay(for: $0) })
        ).sorted(by: >)

        var missing: [Date] = []
        for dayStart in uniqueStarts {
            if let cached = burnedCache.energy(for: dayStart) {
                result[dayStart] = cached
            } else {
                missing.append(dayStart)
            }
        }

        guard let firstMissing = missing.last, let lastMissing = missing.first else {
            return result
        }
        guard let rangeEnd = Calendar.current.date(byAdding: .day, value: 1, to: lastMissing) else {
            return result
        }

        do {
            async let activeByDay = dailySums(for: .activeEnergyBurned, from: firstMissing, to: rangeEnd)
            async let basalByDay = dailySums(for: .basalEnergyBurned, from: firstMissing, to: rangeEnd)
            let activeMap = try await activeByDay
            let basalMap = try await basalByDay

            for dayStart in missing {
                let active = activeMap[dayStart]
                let basal = basalMap[dayStart]
                guard active != nil || basal != nil else { continue }
                let energy = BurnedDayEnergy(
                    dayStart: dayStart,
                    activeBurnedKcal: active ?? 0,
                    basalBurnedKcal: basal ?? 0
                )
                burnedCache.store(energy)
                result[dayStart] = energy
            }
        } catch {
            logger.error(
                "Could not preload Apple Health history: \(error.localizedDescription, privacy: .public)"
            )
            for dayStart in missing {
                if let energy = await burnedEnergy(forDayStarting: dayStart) {
                    result[dayStart] = energy
                }
            }
        }

        return result
    }

    private func dailySums(
        for identifier: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date
    ) async throws -> [Date: Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return [:] }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        let anchor = start
        let interval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: HKSamplePredicate<HKQuantitySample>.quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: anchor,
            intervalComponents: interval
        )

        let collection = try await query.result(for: store)
        var values: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            if let sum = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                values[Calendar.current.startOfDay(for: stats.startDate)] = sum
            }
        }
        return values
    }

    func saveDietaryEnergy(kcal: Double, at date: Date = Date()) async {
        guard isAvailable, isAuthorized, kcal > 0,
              let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        else { return }

        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
            start: date,
            end: date
        )

        do {
            try await store.save(sample)
        } catch {
            logger.error("Could not save food calories to Apple Health: \(error.localizedDescription, privacy: .public)")
            statusMessage = appString("Could not save food calories to Apple Health.")
        }
    }

    private func sumKcal(
        for identifier: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date
    ) async throws -> Double {
        try await sumKcalOptional(for: identifier, from: start, to: end) ?? 0
    }

    private func sumKcalOptional(
        for identifier: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date
    ) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        )
        return try await descriptor.result(for: store)?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())
    }

    private func startObservingHealthData() {
        guard isAvailable, isAuthorized, !isObservingHealthData else { return }
        isObservingHealthData = true

        for identifier in [HKQuantityTypeIdentifier.activeEnergyBurned, .basalEnergyBurned] {
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { continue }

            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                Task { @MainActor [weak self] in
                    if let error {
                        self?.logger.error("Could not update Apple Health data: \(error.localizedDescription, privacy: .public)")
                        self?.statusMessage = appString("Could not update Apple Health data.")
                    } else {
                        await self?.refreshToday()
                    }
                    completion()
                }
            }
            observerQueries.append(query)
            store.execute(query)

            store.enableBackgroundDelivery(for: type, frequency: .hourly) { [weak self] success, error in
                guard !success || error != nil else { return }
                Task { @MainActor [weak self] in
                    if let error {
                        self?.logger.error("Could not enable hourly Apple Health updates: \(error.localizedDescription, privacy: .public)")
                    }
                    self?.statusMessage = appString("Could not enable hourly Apple Health updates.")
                }
            }
        }
    }
}
