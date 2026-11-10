//
//  FoodPreset.swift
//  UFood
//

import Foundation
import Observation
import os

struct FoodPreset: Identifiable, Hashable, Codable {
    enum Category: String, CaseIterable, Identifiable, Codable {
        case fruits
        case vegetables

        var id: String { rawValue }

        var title: String {
            switch self {
            case .fruits: appString("Fruits")
            case .vegetables: appString("Vegetables")
            }
        }
    }

    let id: String
    let kkalsPer100g: Int
    let category: Category
    let defaultGrams: Int
    let nameOverride: String?

    var name: String {
        nameOverride ?? appString("food.\(id)")
    }

    init(
        id: String,
        kkalsPer100g: Int,
        category: Category,
        defaultGrams: Int,
        nameOverride: String? = nil
    ) {
        self.id = id
        self.kkalsPer100g = kkalsPer100g
        self.category = category
        self.defaultGrams = defaultGrams
        self.nameOverride = nameOverride
    }

    static let all: [FoodPreset] = fruits + vegetables

    static let fruits: [FoodPreset] = [
        .init(id: "apple", kkalsPer100g: 52, category: .fruits, defaultGrams: 150),
        .init(id: "banana", kkalsPer100g: 89, category: .fruits, defaultGrams: 120),
        .init(id: "orange", kkalsPer100g: 47, category: .fruits, defaultGrams: 150),
        .init(id: "strawberry", kkalsPer100g: 32, category: .fruits, defaultGrams: 100),
        .init(id: "grapes", kkalsPer100g: 69, category: .fruits, defaultGrams: 100),
        .init(id: "pear", kkalsPer100g: 57, category: .fruits, defaultGrams: 150),
        .init(id: "peach", kkalsPer100g: 39, category: .fruits, defaultGrams: 140),
        .init(id: "watermelon", kkalsPer100g: 30, category: .fruits, defaultGrams: 200),
        .init(id: "blueberry", kkalsPer100g: 57, category: .fruits, defaultGrams: 80),
        .init(id: "kiwi", kkalsPer100g: 61, category: .fruits, defaultGrams: 80),
        .init(id: "mango", kkalsPer100g: 60, category: .fruits, defaultGrams: 150),
        .init(id: "pineapple", kkalsPer100g: 50, category: .fruits, defaultGrams: 120),
    ]

    static let vegetables: [FoodPreset] = [
        .init(id: "tomato", kkalsPer100g: 18, category: .vegetables, defaultGrams: 120),
        .init(id: "cucumber", kkalsPer100g: 15, category: .vegetables, defaultGrams: 100),
        .init(id: "carrot", kkalsPer100g: 41, category: .vegetables, defaultGrams: 80),
        .init(id: "broccoli", kkalsPer100g: 34, category: .vegetables, defaultGrams: 100),
        .init(id: "spinach", kkalsPer100g: 23, category: .vegetables, defaultGrams: 80),
        .init(id: "potato", kkalsPer100g: 77, category: .vegetables, defaultGrams: 150),
        .init(id: "onion", kkalsPer100g: 40, category: .vegetables, defaultGrams: 80),
        .init(id: "bell-pepper", kkalsPer100g: 31, category: .vegetables, defaultGrams: 100),
        .init(id: "lettuce", kkalsPer100g: 15, category: .vegetables, defaultGrams: 60),
        .init(id: "cabbage", kkalsPer100g: 25, category: .vegetables, defaultGrams: 100),
        .init(id: "zucchini", kkalsPer100g: 17, category: .vegetables, defaultGrams: 120),
        .init(id: "corn", kkalsPer100g: 86, category: .vegetables, defaultGrams: 100),
    ]

    static func presets(for category: Category) -> [FoodPreset] {
        switch category {
        case .fruits: fruits
        case .vegetables: vegetables
        }
    }
}

@MainActor
@Observable
final class FoodPresetStore {
    private struct Configuration: Codable {
        var overrides: [String: PresetValues] = [:]
        var customPresets: [FoodPreset] = []
        var deletedPresetIDs: Set<String> = []
    }

    private struct PresetValues: Codable {
        let name: String
        let kkalsPer100g: Int
        let defaultGrams: Int
        let category: FoodPreset.Category
    }

    private enum PresetError: LocalizedError {
        case invalidValues

        var errorDescription: String? {
            appString("Enter a name and positive kcal and gram values.")
        }
    }

    private let defaults: UserDefaults
    private var overrides: [String: PresetValues]
    private var customPresets: [FoodPreset]
    private var deletedPresetIDs: Set<String>
    private(set) var errorMessage: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: AppStorageKey.foodPresets) {
            do {
                let configuration = try JSONDecoder().decode(Configuration.self, from: data)
                overrides = configuration.overrides
                customPresets = configuration.customPresets
                deletedPresetIDs = configuration.deletedPresetIDs
            } catch {
                overrides = [:]
                customPresets = []
                deletedPresetIDs = []
                errorMessage = error.localizedDescription
                Logger(subsystem: Bundle.main.bundleIdentifier ?? "UFood", category: "presets")
                    .error("Could not load food presets: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            overrides = [:]
            customPresets = []
            deletedPresetIDs = []
        }
    }

    func presets(for category: FoodPreset.Category) -> [FoodPreset] {
        let builtIn = FoodPreset.all.compactMap { preset -> FoodPreset? in
            guard !deletedPresetIDs.contains(preset.id) else { return nil }
            if let values = overrides[preset.id] {
                return FoodPreset(
                    id: preset.id,
                    kkalsPer100g: values.kkalsPer100g,
                    category: values.category,
                    defaultGrams: values.defaultGrams,
                    nameOverride: values.name
                )
            }
            return preset
        }.filter { $0.category == category }
        return builtIn + customPresets.filter { $0.category == category }
    }

    func update(
        _ preset: FoodPreset,
        name: String,
        kkalsPer100g: Int,
        defaultGrams: Int,
        category: FoodPreset.Category
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, kkalsPer100g > 0, defaultGrams > 0 else {
            throw PresetError.invalidValues
        }

        var configuration = currentConfiguration
        if let index = configuration.customPresets.firstIndex(where: { $0.id == preset.id }) {
            configuration.customPresets[index] = FoodPreset(
                id: preset.id,
                kkalsPer100g: kkalsPer100g,
                category: category,
                defaultGrams: defaultGrams,
                nameOverride: trimmedName
            )
        } else {
            configuration.overrides[preset.id] = PresetValues(
                name: trimmedName,
                kkalsPer100g: kkalsPer100g,
                defaultGrams: defaultGrams,
                category: category
            )
        }
        try save(configuration)
    }

    func add(
        name: String,
        kkalsPer100g: Int,
        category: FoodPreset.Category,
        defaultGrams: Int
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, kkalsPer100g > 0, defaultGrams > 0 else {
            throw PresetError.invalidValues
        }

        var configuration = currentConfiguration
        configuration.customPresets.append(
            FoodPreset(
                id: UUID().uuidString,
                kkalsPer100g: kkalsPer100g,
                category: category,
                defaultGrams: defaultGrams,
                nameOverride: trimmedName
            )
        )
        try save(configuration)
    }

    func delete(_ preset: FoodPreset) throws {
        var configuration = currentConfiguration
        if configuration.customPresets.contains(where: { $0.id == preset.id }) {
            configuration.customPresets.removeAll { $0.id == preset.id }
        } else {
            configuration.overrides.removeValue(forKey: preset.id)
            configuration.deletedPresetIDs.insert(preset.id)
        }
        try save(configuration)
    }

    func restoreBuiltInPresets() throws {
        var configuration = currentConfiguration
        configuration.overrides = [:]
        configuration.deletedPresetIDs = []
        try save(configuration)
    }

    func clearError() {
        errorMessage = nil
    }

    private var currentConfiguration: Configuration {
        Configuration(
            overrides: overrides,
            customPresets: customPresets,
            deletedPresetIDs: deletedPresetIDs
        )
    }

    private func save(_ configuration: Configuration) throws {
        do {
            let data = try JSONEncoder().encode(configuration)
            defaults.set(data, forKey: AppStorageKey.foodPresets)
            overrides = configuration.overrides
            customPresets = configuration.customPresets
            deletedPresetIDs = configuration.deletedPresetIDs
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
