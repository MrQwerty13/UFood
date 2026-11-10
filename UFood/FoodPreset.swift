//
//  FoodPreset.swift
//  UFood
//

import Foundation

struct FoodPreset: Identifiable, Hashable {
    enum Category: String, CaseIterable, Identifiable {
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

    var name: String {
        appString("food.\(id)")
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
