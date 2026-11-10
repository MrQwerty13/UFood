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
    var activeBurnedKcal: Int?
    var restingBurnedKcal: Int?
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

    var totalBurnedKcal: Int? {
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
            async let active = sumToday(for: .activeEnergyBurned)
            async let resting = sumToday(for: .basalEnergyBurned)
            activeBurnedKcal = Int((try await active).rounded())
            restingBurnedKcal = Int((try await resting).rounded())
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

    private func sumToday(for identifier: HKQuantityTypeIdentifier) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }

        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: Date(),
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
