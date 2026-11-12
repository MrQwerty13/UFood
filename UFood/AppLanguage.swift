//
//  AppLanguage.swift
//  UFood
//

import Foundation

nonisolated enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case russian

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .system: "language.system"
        case .english: "language.english"
        case .russian: "language.russian"
        }
    }

    var title: String {
        appString(titleKey)
    }

    var locale: Locale {
        switch resolvedLanguage {
        case .english: Locale(identifier: "en")
        case .russian: Locale(identifier: "ru")
        case .system: Locale(identifier: "en")
        }
    }

    var promptLanguageName: String {
        switch resolvedLanguage {
        case .system: "English"
        case .english: "English"
        case .russian: "Russian"
        }
    }

    private var resolvedLanguage: AppLanguage {
        guard self == .system else { return self }
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        return preferredLanguage.hasPrefix("ru") ? .russian : .english
    }

    static func resolved(from rawValue: String) -> AppLanguage {
        AppLanguage(rawValue: rawValue) ?? .system
    }
}

/// Looks up a localized string using the language selected in Settings
/// (uses the device language when `.system` is selected).
nonisolated func appString(_ key: String) -> String {
    let raw = UserDefaults.standard.string(forKey: AppStorageKey.language) ?? AppLanguage.system.rawValue
    let language = AppLanguage.resolved(from: raw)

    guard let path = Bundle.main.path(forResource: language.locale.identifier, ofType: "lproj"),
          let bundle = Bundle(path: path)
    else {
        return NSLocalizedString(key, comment: "")
    }

    return NSLocalizedString(key, bundle: bundle, comment: "")
}
