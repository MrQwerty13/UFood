//
//  HealthKitManager.swift
//  UFood
//

import Foundation
import HealthKit

@MainActor
@Observable
final class HealthKitManager {
    private let store = HKHealthStore()
    var isAuthorized: Bool {
        didSet { UserDefaults.standard.set(isAuthorized, forKey: AppStorageKey.healthConnected) }
    }
    var activeBurnedKcal: Double?
    var restingBurnedKcal: Double?
    var statusMessage: String?
    var isLoading = false
    private var observerQueries: [HKObserverQuery] = []
    private var isObservingHealthData = false

    init() {
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
            statusMessage = "Apple Health is not available on this device."
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
            statusMessage = error.localizedDescription
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
            statusMessage = error.localizedDescription
        }
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
            statusMessage = error.localizedDescription
        }
    }

    private func sumKcal(
        for identifier: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date
    ) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }

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
            .doubleValue(for: .kilocalorie()) ?? 0
    }

    private func startObservingHealthData() {
        guard isAvailable, isAuthorized, !isObservingHealthData else { return }
        isObservingHealthData = true

        for identifier in [HKQuantityTypeIdentifier.activeEnergyBurned, .basalEnergyBurned] {
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { continue }

            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                Task { @MainActor [weak self] in
                    if let error {
                        self?.statusMessage = error.localizedDescription
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
                    self?.statusMessage = error?.localizedDescription
                        ?? "Could not enable hourly Apple Health updates."
                }
            }
        }
    }
}
