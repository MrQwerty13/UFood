//
//  FoodTag.swift
//  UFood
//

import Foundation
import Observation

struct FoodTag: Identifiable, Hashable {
    let id: String
    private let titleKey: String?

    var title: String {
        titleKey.map(appString) ?? id
    }

    private init(id: String, titleKey: String?) {
        self.id = id
        self.titleKey = titleKey
    }

    static let defaultTags = [
        FoodTag(id: "fruits", titleKey: "Fruits"),
        FoodTag(id: "vegetables", titleKey: "Vegetables"),
        FoodTag(id: "drinks", titleKey: "Drinks"),
        FoodTag(id: "snacks", titleKey: "Snacks"),
    ]

    static func title(for id: String) -> String {
        defaultTags.first(where: { $0.id == id })?.title ?? id
    }

    fileprivate static func custom(_ name: String) -> FoodTag {
        FoodTag(id: name, titleKey: nil)
    }
}

@MainActor
@Observable
final class FoodTagStore {
    private enum TagError: LocalizedError {
        case empty
        case alreadyExists

        var errorDescription: String? {
            switch self {
            case .empty: appString("Enter a tag name.")
            case .alreadyExists: appString("A tag with this name already exists.")
            }
        }
    }

    private let defaults: UserDefaults
    private(set) var customTags: [String]
    private(set) var errorMessage: String?

    var tags: [FoodTag] {
        FoodTag.defaultTags + customTags.map(FoodTag.custom)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        customTags = defaults.stringArray(forKey: AppStorageKey.foodTags) ?? []
    }

    func add(_ name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw TagError.empty
        }
        guard !tags.contains(where: { $0.title.caseInsensitiveCompare(trimmedName) == .orderedSame }) else {
            throw TagError.alreadyExists
        }

        customTags.append(trimmedName)
        defaults.set(customTags, forKey: AppStorageKey.foodTags)
        errorMessage = nil
    }
}
