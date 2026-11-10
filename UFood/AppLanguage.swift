//
//  AppLanguage.swift
//  UFood
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case russian
    case spanish
    case german

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .system: "language.system"
        case .english: "language.english"
        case .russian: "language.russian"
        case .spanish: "language.spanish"
        case .german: "language.german"
        }
    }

    var title: String {
        appString(titleKey)
    }

    /// Locale used for in-app strings. `nil` follows the system language.
    var locale: Locale? {
        switch self {
        case .system: nil
        case .english: Locale(identifier: "en")
        case .russian: Locale(identifier: "ru")
        case .spanish: Locale(identifier: "es")
        case .german: Locale(identifier: "de")
        }
    }

    var promptLanguageName: String {
        switch self {
        case .system:
            Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en") ?? "English"
        case .english: "English"
        case .russian: "Russian"
        case .spanish: "Spanish"
        case .german: "German"
        }
    }

    static func resolved(from rawValue: String) -> AppLanguage {
        AppLanguage(rawValue: rawValue) ?? .system
    }
}

/// Looks up a localized string using the language selected in Settings
/// (falls back to the system language when `.system` is selected).
func appString(_ key: String) -> String {
    let raw = UserDefaults.standard.string(forKey: AppStorageKey.language) ?? AppLanguage.system.rawValue
    let language = AppLanguage.resolved(from: raw)

    guard let code = language.locale?.identifier,
          let path = Bundle.main.path(forResource: code, ofType: "lproj"),
          let bundle = Bundle(path: path)
    else {
        return NSLocalizedString(key, comment: "")
    }

    return NSLocalizedString(key, bundle: bundle, comment: "")
}
